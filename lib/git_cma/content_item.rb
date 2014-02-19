require 'ostruct'

module GitCma
  # Public: Structured content storage. Uses `Document` for versioning and publishing pipeline support.
  # Content can be any data structure composed of hashes and arrays. It is then accessible through method
  # calls (similar to OpenStruct which it is based on). When saved, content item serializes the content
  # to JSON and saves it. Loading a content item automatically constructs the data structure from the JSON.
  #
  # You can list and search the content items using the `list` and `search` class methods.
  #
  # If you need to customize the search behavior - change the index name, the type name or the attributes indexing,
  # You will need to inherit the ContentItem class. Let's take an example, an Article class that has a `title`, an
  # `abstract` a `body` and a `published_at` date.
  #
  # ```ruby
  # class Document
  #   index_name = 'my_app_index'
  #   item_type_name = 'article'
  #
  #   attributes_mapping do
  #     {
  #       title: { type: 'string' },
  #       abstract: { type: 'string' },
  #       body: { type: 'string' },
  #       published_at: { type: 'date' },
  #     }
  #   end
  # end
  # ```
  #
  class ContentItem
    attr_reader :document, :id

    def initialize(content, opts = {})
      @document = opts[:document] || Document.new
      @content = if @document.content && !@document.content.empty?
        Content.from_json(@document.content)
      else
        Content.new(content)
      end

      @id = @document.name
    end

    def update(content)
      @content.update(content)
    end

    def delete_field(field)
      @content.delete_field(field)
    end

    def save!(timestamp)
      document.content = @content.to_json
      sha = document.save!(timestamp)

      index!(state: 'master', updated_at: timestamp, revision: sha)

      sha
    end

    def index!(opts = {})
      state = opts[:state] || 'master'
      updated_at = opts[:updated_at]
      sha = opts[:revision]

      body = {
        id: id,
        revision: sha,
        state: state,
        updated_at: updated_at
      }

      body = body.merge(@content.plain)

      item_id = "#{@id}-#{state}"
      rev_id = "#{@id}-#{sha}"

      # Index the document
      self.class.es_client.index(index: self.class.index_name, type: self.class.item_type_name.to_s, id: item_id, body: body)

      # Index the revision
      self.class.es_client.index(index: self.class.index_name, type: self.class.revision_type_name.to_s, id: rev_id, parent: item_id, body: body)
    end

    def load!(rev)
      rev = document.load!(rev)
      @content = Content.from_json(document.content)

      rev
    end

    # Surfacing document API

    def revision
      document.revision
    end

    def history(state = nil, &block)
      document.history(state, &block)
    end

    def promote!(from, to, message, timestamp)
      sha = document.promote!(from, to, message, timestamp)

      index!(state: to, revision: sha, updated_at: timestamp)

      sha
    end

    def has_been_promoted?(to, rev = nil)
      document.has_been_promoted?(to, rev)
    end

    def rollback!(state)
      document.rollback!(state)

      # FIXME index the document back to the current revision!
    end

    # Surfacing content

    def [](i)
      @content[i]
    end

    def []=(i, val)
      @content[i] = value
    end

    def method_missing(meth, *args)
      if args.length < 1
        @content.send meth
      elsif args.length == 1
        @content.send meth.to_s.chomp("="), *args
      else
        super
      end
    end

    class << self
      def open(id, rev = nil)
        doc = Document.open(id, rev)
        new(nil, document: doc)
      end

      # Public: List all the content items. Supports filtering by state, sorting and pagination.
      #
      # opts  - options hash
      #         :state - state to filter to
      #         :sort  - sort specification for ES. ex.: {updated_at: 'desc'} or [{...}, {...}].
      #                  Wrapped in an array automatically.
      #         :from  - how many results to skip
      #         :size  - how many results to return
      #
      # Returns the elasticsearch result set
      def list(opts = {})
        state = opts[:state] || 'master'

        query = { query: { constant_score: { filter: { term: { state: state } }}}}

        query[:from] = opts[:from] if opts[:from]
        query[:size] = opts[:size] if opts[:size]

        query[:sort] = opts[:sort] if opts[:sort]
        query[:sort] = [query[:sort]] if query[:sort] && !query[:sort].is_a?(Array)


        res = es_client.search(index: index_name, type: item_type_name.to_s, body: query)

        hydrate_hits(res["hits"])
      end

      # Search: Generic search support, delegates to elasticsearch. Searches all documents of type [item_type_name].
      # If versions option is set to true, returns such documents which have a child matching the query, i.e. versions.
      # In essence you search through all the versions and get
      # the documents having a matching version get.
      #
      # query - string, or elastic search query DSL. Forwarded to elasticsearch
      # opts  - an options hash
      #         :history - boolean, search across all revisions. Default false.
      #         :sort - sort specification
      #         :from - how many results to skip
      #         :size - how many results to show
      # Returns the elasticsearch result set
      def search(query, opts = {})
        query = { query_string: { query: query }} if query.is_a?(String)
        query = { has_child: { type: revision_type_name.to_s, query: query }} if opts[:history]

        body = { query: query }

        body[:from] = opts[:from] if opts[:from]
        body[:size] = opts[:size] if opts[:size]

        body[:sort] = opts[:sort] if opts[:sort]
        body[:sort] = [body[:sort]] if body[:sort] && !body[:sort].is_a?(Array)

        res = es_client.search(index: index_name, type: item_type_name.to_s, body: body)

        hydrate_hits(res["hits"])
      end

      # Public: Item type name for elasticsearch
      def item_type_name(val = nil)
        @item_type_name = val if val
        @item_type_name || 'content_item'
      end

      # Public: Index name in elasticsearch
      def index_name(val = nil)
        @index_name = val if val
        @index_name || 'git-cma-content'
      end

      def attributes_mapping(&block)
        extra_properties = yield

        @mapping = default_mapping
        @mapping[:properties].merge(extra_properties)

        # TODO put mapping
      end

      def mapping
        @mapping || default_mapping
      end

      # Public: The Elasticsearch client
      def es_client
        @es_client ||= ::Elasticsearch::Client.new log: false
      end

      # Internal: Revision type name for elastic search.
      def revision_type_name
        item_type_name + "_rev"
      end

      # Internal: idempotently create the ES index
      def ensure_index!
        unless es_client.indices.exists index: index_name
          body = { mappings: {} }
          body[:mappings][item_type_name] = ITEM_MAPPING
          body[:mappings][revision_type_name] = mapping

          es_client.indices.create index: index_name, body: body
        end
      end

      private

      def hydrate_hits(hits)
        hits["hits"] = hits["hits"].map do |hit|
          open(hit["_source"]["id"])
        end

        # FIXME this should probably be a result set class with Enumerable mixin
        {total: hits["total"], hits: hits["hits"]}
      end

      # Revision mapping, used for all other types of search through parent-child relation on the item
      def default_mapping
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
    end

    # Item mapping, used for listing documents
    ITEM_MAPPING = {
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
