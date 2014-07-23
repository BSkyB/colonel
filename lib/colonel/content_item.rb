require 'ostruct'

module Colonel
  # DEPRECATED
  # Public: Structured content storage. Backed by `Document` for versioning and publishing states support.
  # Content can be any data structure composed of hashes and arrays. It is then accessible through method
  # calls (similar to OpenStruct which it is based on). When saved, content item serializes the content
  # to JSON and saves it. Loading a content item automatically constructs the data structure from the JSON.
  #
  # You can list and search the content items using the `list` and `search` class methods.
  #
  # If you need to customize the search behavior - change the index name, the type name or the attributes
  # indexing, you will need to inherit the ContentItem class.
  #
  # Examples
  #
  # Let's take an example, an Article class that has a `title`, an
  # `abstract` a `body` and a `published_at` date.
  #
  #   class Document
  #     index_name 'my_app_index'
  #     item_type_name 'article'
  #
  #     attributes_mapping do
  #       {
  #         title: { type: 'string' },
  #         abstract: { type: 'string' },
  #         body: { type: 'string' },
  #         published_at: { type: 'date' },
  #       }
  #     end
  #   end
  #
  class ContentItem
    attr_reader :document, :id

    # Public: create a new content item
    #
    # content - the item content - a Hash or an Array instance, the content of which will be accessible
    #           on the content item.
    #
    # Examples
    #
    #   item = ContentItem.new(name: {first: 'John', last: 'Doe'}, tags: ['Staff', 'Management'])
    #   item.name.first
    #   # => 'John'
    #
    #   item.tags[1]
    #   # => 'Management'
    def initialize(content, opts = {})
      @document = opts[:document] || Document.new(self.class.item_type_name)
      @content = if @document.content && !@document.content.empty?
        Content.from_json(@document.content)
      else
        Content.new(content)
      end

      @id = @document.name
    end


    class << self
      # Public: Open a content item by it's id and optionally revision. Delegates to the document.
      def open(id, rev = nil)
        doc = Document.open(id, rev)
        return nil unless doc

        new(nil, document: doc)
      end



      # Search: Generic search support, delegates to elasticsearch. Searches all documents of type [item_type_name].
      # If history option is set to true, returns such documents which have a child matching the query, i.e. versions.
      # In essence you search through all the versions and get
      # the documents having a matching version get.
      #
      # query - string, or elastic search query DSL. Forwarded to elasticsearch
      # opts  - an options hash
      #         :history - boolean, search across all revisions. Default false.
      #         :scope - filter search to a custom scope
      #         :sort - sort specification
      #         :from - how many results to skip
      #         :size - how many results to show
      #
      # Returns the elasticsearch result set
      def search(query, opts = {raw: false})
        query = { query: { query_string: { query: query }} } if query.is_a?(String)
        query = { query: { has_child: { type: revision_type_name.to_s }.merge(query) } } if opts[:history]

        body = query

        body[:from] = opts[:from] if opts[:from]
        body[:size] = opts[:size] if opts[:size]

        body[:sort] = opts[:sort] if opts[:sort]
        body[:sort] = [body[:sort]] if body[:sort] && !body[:sort].is_a?(Array)

        if opts[:scope]
          item_type = "#{item_type_name.to_s}_#{opts[:scope]}"
        else
          item_type = "#{item_type_name.to_s}"
        end

        res = es_client.search(index: index_name, type: item_type, body: body)

        hydrate_hits(res, opts)
      end

      def scope(name, predicates)
        @scopes ||= {}
        @scopes[name] = predicates
      end

      def scopes
        @scopes ||= {}
      end

      # Public: Set or retrieve the ittem type in elasticsearch
      def item_type_name(val = nil)
        @item_type_name = val if val
        @item_type_name || 'content_item'
      end

      # Public: Set or retrieve the index name in elasticsearch
      def index_name(val = nil)
        @index_name = val if val
        @index_name || Colonel.config.index_name
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
        extra_properties = yield

        @item_mapping = default_item_mapping
        @item_mapping[:properties] = @item_mapping[:properties].merge(extra_properties)

        @revision_mapping = default_revision_mapping
        @revision_mapping[:properties] = @revision_mapping[:properties].merge(extra_properties)
      end

      # Internal: Mapping for the item type
      def item_mapping
        @item_mapping || default_item_mapping
      end

      # Internal: Mapping for the revision type
      def revision_mapping
        @revision_mapping || default_revision_mapping
      end

      # Public: The Elasticsearch client
      def es_client
        @es_client ||= ::Elasticsearch::Client.new(host: Colonel.config.elasticsearch_uri, log: false)
      end

      # Internal: Revision type name for elastic search.
      def revision_type_name
        item_type_name + "_rev"
      end


      private

      # Internal: Default revision mapping, used for all search in history
      def default_revision_mapping
        {
          _source: { enabled: false }, # you only get what you store
          _parent: { type: item_type_name },
          properties: {
            # _id is "{id}-{rev}"
            id: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            revision: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            state: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            updated_at: {
              type: 'date'
            }
          }
        }
      end

      # Internal: Default item mapping
      def default_item_mapping
        {
          properties: {
            # _id is "{id}-{state}"
            id: {
              type: 'string',
              index: 'not_analyzed'
            },
            state: {
              type: 'string',
              index: 'not_analyzed'
            },
            updated_at: {
              type: 'date'
            }
          }
        }
      end
    end
  end
end
