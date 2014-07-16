module Colonel
  class Revision
    attr_reader :content, :author, :message, :timestamp

    def initialize(document, content, author, message, timestamp, previous, origin = nil, commit = nil)
      @document = document
      @commit = commit

      @content = content
      @author = author
      @message = message
      @timestamp = timestamp
      @previous = previous
      @origin = origin
    end

    def id
      @commit.oid unless @commit.nil?
    end

    def previous
      return nil if @previous.nil?

      @previous = document.revisions[@previous] if @previous.is_a?(String)

      @previous
    end

    def origin
      return nil if @origin.nil?
    end

    def content
      return @content if @content.is_a?(Content)

      # lazy load content
      tree = @commit.tree
      file = @document.repository.lookup(tree.first[:oid]).read_raw

      @content = Content.from_json(file.data)
    end

    def write!(repository, update_ref = nil)
      return unless @id.nil?
      oid = repository.write(@content.to_json, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)

      parents = [previous, origin].compact
      parents = parents.map(&:id).compact unless parents.empty?

      commit_options = {
        tree: tree,
        author: author,
        committer: author,
        message: message,
        parents: parents,
      }
      commit_options[:update_ref] = update_ref if update_ref

      @id = Rugged::Commit.create(repository, commit_options)
    end

    class << self
      def from_commit(document, commit)
        previous = commit.parents[0]
        origin = commit.parents[1]

        new(document, nil, commit.author, commit.message, commit.time, previous, origin, commit)
      end
    end
  end
end
