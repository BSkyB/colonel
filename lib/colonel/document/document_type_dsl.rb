module Colonel
  # Public: Configuration DSL for DocumentType
  class DocumentTypeDSL
    attr_reader :config

    # Internal: create a new DSL instance
    def initialize
      @config = Struct.new(:search_provider, :index_name, :custom_mapping, :scopes).new
      @config.scopes = {}
    end

    # Public: Define a search provider for the type. If you don't want search support for
    # your type, pass in a non-nil value that is not an instance of ElasticsearchProvide, e.g. :none
    #
    # Example
    #
    #   `search_provider :none`
    def search_provider(provider)
      config.search_provider = provider
    end

    # Public: Set special index name for this type
    def index_name(name)
      config.index_name = name
    end

    # Public: Set custom mapping for your content structure. Yields to a block that
    # should return a hash with the attributes mapping.
    #
    # Examples
    #
    #   attributes_mapping do
    #     {
    #       tags: {
    #         type: "string",
    #         index: "not_analyzed", # we only want exact matches
    #         boost: 2 # boost tags when searching
    #       }
    #     }
    #   end
    def attributes_mapping(&block)
      config.custom_mapping = yield
    end

    # Public: Define custom scopes
    #
    # name        - name of the scope, which you can use to scope the search
    # predicates  - hash with keys
    #               :on - string or array - events to track in the scope (save, promotion)
    #               :to - string or array - target states to track
    #
    # Examples
    #
    #   scope 'visible', on: 'promotion', to: ['published', 'archived']
    #
    # will index on each promotion to published and archived state
    def scope(name, predicates)
      config.scopes[name] = predicates
    end
  end
end
