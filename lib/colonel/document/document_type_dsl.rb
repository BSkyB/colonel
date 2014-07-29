module Colonel
  class DocumentTypeDSL
    attr_reader :config

    def initialize
      @config = Struct.new(:search_provider, :index_name, :custom_mapping, :scopes).new
      @config.scopes = {}
    end

    def search_provider(provider)
      config.search_provider = provider
    end

    # Public: override index name (use when subclassing)
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
    # TODO more docs
    def scope(name, predicates)
      config.scopes[name] = predicates
    end
  end
end
