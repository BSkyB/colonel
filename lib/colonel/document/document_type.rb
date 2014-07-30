require "colonel/document/document_type_dsl"

module Colonel
  # Public: DocumentType allows you to define custom types of documents and override
  # default search configuration - attributes mapping, index name and scope
  #
  # See `DocumentTypeDSL` for information about configuring the type
  class DocumentType
    attr_reader :type, :index_name, :custom_mapping, :scopes

    def initialize(type, &block)
      @type = type

      dsl = DocumentTypeDSL.new
      dsl.instance_eval(&block) if block_given?

      @index_name = dsl.config.index_name
      @search_provider_class = dsl.config.search_provider_class || ElasticsearchProvider
      @custom_mapping = dsl.config.custom_mapping
      @scopes = dsl.config.scopes

      DocumentType.register(type, self)
    end

    # Public: get the search provider
    def search_provider
      return @search_provider unless @search_provider.nil?
      return nil unless @search_provider_class.is_a?(Class)

      @search_provider = @search_provider_class.new(index_name, self, custom_mapping, scopes)
    end

    # Public: create a new document
    #
    # content - Hash or an Array content of the document
    # options - an options Hash with extra attributes
    #           :repo    - rugged repository object when loading an existing document. (optional).
    #                      Not meant to be used directly
    def new(raw_content, opts = {})
      opts[:type] = self
      Document.new(raw_content, opts)
    end

    # Public: Open the document specified by `id`, optionally at a revision `rev`
    #
    # id  - id of the document
    # rev   - revision to load (optional)
    #
    # Returns a Document instance
    def open(id, rev = nil)
      begin
        unless Colonel.config.rugged_backend.nil?
          repo = Rugged::Repository.bare(File.join(Colonel.config.storage_path, id), backend: Colonel.config.rugged_backend)
        else
          repo = Rugged::Repository.bare(File.join(Colonel.config.storage_path, id))
        end
      rescue Rugged::OSError
        return nil
      end

      Document.new(nil, id: id, repo: repo, type: self)
    end

    # Public: List all the documents of this type. See ElasticsearchProvider#list
    def list(opts = {})
      search_provider.list(opts)
    end

    # Public: Search documents of this type. See ElasticsearchProvider#search
    def search(*args)
      search_provider.search(*args)
    end

    class << self
      # Internal: Register a new type for a given name
      def register(type_name, type)
        @types ||= {}

        @types[type_name] = type
      end

      # Public: Get the DocumentType instance for a nem
      #
      # type_name - string, name of the type, e.g. 'document'
      def get(type_name)
        @types ||= {}
        register_default unless @types['document']

        type = @types[type_name]
        raise RuntimeError, "Unknown Type #{type} (know #{@types.keys.join(',')})" unless type

        type
      end

      # Public: Iterate through all the known types
      #
      # Returns an iterator if no block is passed, otherwise yields a (name, type) pair to the block
      def all(&block)
        to_enum(:all) unless block_given?

        @types ||= {}
        register_default unless @types['document']

        @types.each(&block)
      end

      private

      def register_default
        DocumentType.new('document')
      end
    end
  end
end
