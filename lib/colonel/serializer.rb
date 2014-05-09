require "base64"

module Colonel
  # Public: a serialization tool for Colonel::Document
  class Serializer

    class << self

      # Public: serializes a document with full history and writes to a stream
      #
      # document - a Document instance
      # ostream  - an instance of IO to write to
      def generate(document, ostream)
        ostream.write "document: #{document.name}\n"
        ostream.write "references:\n"
        ostream.write serialize_hash({name: "HEAD", type: :symbolic, target: "refs/heads/master"})
        ostream.write("\n")

        repo = document.repository

        repo.references.each do |ref|
          ostream.write(serialize_hash({name: ref.name, type: :oid, target: ref.target_id}))
          ostream.write("\n")
        end

        ostream.write "objects:\n"

        root_oid = repo.references["refs/tags/root"].target_id
        write_commit(ostream, repo, root_oid, repo.lookup(root_oid))

        repo.references.each do |ref|
          oid = ref.target_id
          while(oid && oid != root_oid)
            commit = repo.lookup(oid)
            write_commit(ostream, repo, oid, commit)

            break if commit.parent_ids.empty?
            oid = commit.parent_ids.first # walk down only
          end
        end
      end

      # Public: loads a document from a string produced by `generate`
      #
      # istream   - input stream to read from
      #
      # returns a document instance
      def load(stream)
        header = stream.readline
        match = header.match(/^document:\s*(.+)$/)
        raise RuntimeError, "Malformed document header" if match[1].empty?

        document = Document.new(match[1])
        repo = document.repository

        raise RuntimeError, "Malformed document header" unless stream.readline =~ /^references:$/

        line = stream.readline
        until(line =~ /^objects:$/)
          ref = load_hash(line) rescue raise(RuntimeError, "expected reference, found: #{line}")

          if repo.references[ref['name']]
            repo.references.update(ref["name"], ref["target"])
          else
            repo.references.create(ref["name"], ref["target"])
          end

          line = stream.readline
        end

        # read the rest of the stream
        while(line = stream.readline)
          obj = load_hash(line) rescue raise(RuntimeError, "expected object, found: #{line}")
          data = Base64.strict_decode64(obj['data'])

          raise RuntimeError, "Data length mismatch! dump: #{obj["len"]}, actuall: #{data.bytesize}" unless data.bytesize == obj['len']

          oid = repo.write(data, obj['type'].to_sym)
          raise RuntimeError, "oid mismatch! read: #{obj["oid"]}, got: #{oid}" unless oid == obj['oid']

          break if stream.eof?
        end

        document.load!
        document
      end

      private

      def write_commit(stream, repo, oid, commit)
        write_object(stream, oid, commit)

        tree = commit.tree
        write_object(stream, tree.oid, tree)

        content_id = tree.first[:oid]
        content = repo.lookup(content_id)

        write_object(stream, content_id, content)
      end

      def write_object(stream, id, object)
        raw = object.read_raw
        hash = {oid: raw.oid, type: raw.type, data: Base64.strict_encode64(raw.data).strip, len: raw.len}

        stream.write(serialize_hash(hash))
        stream.write("\n")
      end

      def serialize_hash(hash)
        JSON.generate(hash)
      end

      def load_hash(string)
        JSON.parse(string)
      end
    end
  end
end
