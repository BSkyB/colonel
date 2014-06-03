module Colonel
  # Public: Document index holding the list of all documents in a given `storage_path`. This is a low-leve
  # document manifest used for maintenance - e.g. backup and restore, or reindexing in elasticsearch.
  # You should only use this class if you're not using the ContentItem at all or for Colonel-level tools.
  #
  # Internally the index is a file in a git repo-like storage: A single ref to a blob object that gets
  # updated every time the index changes.
  class DocumentIndex
    INDEX_NAME = 'colonel/document-index'

    attr_reader :storage_path

    # Public: Get an index for a given `storage_path`, where documents are stored. You almost never
    # need to do this directly, `Document` does it for you.
    def initialize(storage_path)
      @storage_path = storage_path
    end

    # Public: List all the documents this index is aware of.
    #
    # returns an array of document names as strings
    def documents
      return @documents if @documents

      begin
        rev = repository.head.target_id
      rescue Rugged::ReferenceError
        return @documents = []
      end

      file = repository.lookup(rev).read_raw.data
      @documents = file.split("\n").map do |d|
        parts = d.split(' ')
        {name: parts[0].strip, type: (parts[1] || "").strip }
      end
    end

    # Public: Idempotently register a document. If the document isn't yet known, it will be added to the
    # index.
    def register(document_name, document_type)
      return true if include?(document_name)

      documents << {name: document_name, type: document_type}
      oid = repository.write(documents.map {|d| [d[:name], d[:type]].join(" ") }.join("\n"), :blob)

      ref = repository.references["refs/heads/master"]
      if ref
        repository.references.update(ref, oid)
      else
        repository.references.create("refs/heads/master", oid)
      end

      true
    end

    # Public: lookup a document in the index and return the details
    #
    # return a hash with :name and :type keys
    def lookup(document_name)
      # FIXME - this check is potentially sloooow. We may need a Hash or a trie-like datastructure
      documents.detect {|d| d[:name] == document_name }
    end

    # Public: is document of a given name in the index?
    #
    # returns true if the document is found false otherwise
    def include?(document_name)
      documents.any? {|d| d[:name] == document_name }
    end

    # Internal: repository for the index
    def repository
      unless Colonel.config.rugged_backend.nil?
        @repo ||= Rugged::Repository.init_at(File.join(@storage_path, INDEX_NAME), :bare, backend: Colonel.config.rugged_backend)
      else
        @repo ||= Rugged::Repository.init_at(File.join(@storage_path, INDEX_NAME), :bare)
      end
    end
  end
end
