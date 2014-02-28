require 'ostruct'

module Colonel
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
      @document = opts[:document] || Document.new
      @content = if @document.content && !@document.content.empty?
        Content.from_json(@document.content)
      else
        Content.new(content)
      end

      @id = @document.name
    end

    # Public: bulk update the content. Works the same way as the contructor.
    def update(content)
      @content.update(content)
    end

    # Public: Delete a field from the content, if it's a hash. See OpenStruct documentation for details.
    def delete_field(field)
      @content.delete_field(field)
    end

    # Public: Save the content item and update the search index
    #
    # timestamp - the time of the save
    #
    # Returns the sha of the newly created revision
    def save!(timestamp)
      document.content = @content.to_json
      sha = document.save!(timestamp)

      index!(state: 'master', updated_at: timestamp, revision: sha)

      sha
    end

    # Public: Index the content in elasticsearch. Creates a document for the revision and updates the document
    # for the item, to enable both search of the lates and all the revisions.
    # Document ids have a format docid-state and docid-revisionsha.
    #
    # opts - an options hash with keys
    #        :state - the state of the document
    #        :updated_at - the timestamp
    #        :revision - the sha of the revision
    #
    # Returns nothing
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

    # Public: Load the content item and instantiate the content.
    #
    # rev - state name or sha of the revision to load.
    def load!(rev)
      rev = document.load!(rev)
      @content = Content.from_json(document.content)

      rev
    end

    # Surfacing document API

    # Public: Get the content item's current revision from the document. Delegates to the document.
    def revision
      document.revision
    end

    # Public: Get the content item's history. Delegates to the Document
    def history(state = nil, &block)
      document.history(state, &block)
    end

    # Public: Promote the document to a new state and index the change. Other than indexing, works the same way
    # as in the Document class.
    def promote!(from, to, message, timestamp)
      sha = document.promote!(from, to, message, timestamp)

      index!(state: to, revision: sha, updated_at: timestamp)

      sha
    end

    # Public: Has a given revision (default to current) been promoted to a given state? Delegates to the document.
    def has_been_promoted?(to, rev = nil)
      document.has_been_promoted?(to, rev)
    end

    # Public: Rolls back the document and updates the index accordingly. Delegates to `rollback_index!` and the document.
    def rollback!(state)
      rollback_index!(state)
      document.rollback!(state)
    end

    # Public: Update the index for the rollback of a given state. I.e. remove the latest revision that's being rolled back
    # and update the item's record to the previous revision's content.
    #
    # state - the state to rollback
    def rollback_index!(state)
      ci = self.clone

      history = ci.history(state)
      commit = history[0]
      parent = history[1]

      from_sha = commit[:rev]
      to_sha = parent[:rev]
      updated_at = parent[:time]

      ci.load!(to_sha)

      body = {
        id: ci.id,
        revision: to_sha,
        state: state,
        updated_at: updated_at
      }

      item_id = "#{ci.id}-#{state}"
      rev_id = "#{ci.id}-#{from_sha}"

      body = body.merge(Content.from_json(ci.document.content).plain)

      # reindex the document
      self.class.es_client.index(index: self.class.index_name, type: self.class.item_type_name.to_s, id: item_id, body: body)

      # delete the old revision
      self.class.es_client.delete(index: self.class.index_name, type: self.class.revision_type_name.to_s, id: rev_id)

      to_sha
    end

    # Surfacing content

    # Public: Array like content reader
    def [](i)
      @content[i]
    end

    # Public: Array like content writer
    def []=(i, val)
      @content[i] = value
    end

    # Internal: Forward relevant methods to the content to allow more natural API
    def method_missing(meth, *args)
      if args.length < 1
        @content.send meth
      elsif meth.to_s.match(/=$/) && args.length == 1
        @content.send meth, *args
      else
        super
      end
    end

    class << self
      # Public: Open a content item by it's id and optionally revision. Delegates to the document.
      def open(id, rev = nil)
        doc = Document.open(id, rev)
        return nil unless doc

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
      # If history option is set to true, returns such documents which have a child matching the query, i.e. versions.
      # In essence you search through all the versions and get
      # the documents having a matching version get.
      #
      # query - string, or elastic search query DSL. Forwarded to elasticsearch
      # opts  - an options hash
      #         :history - boolean, search across all revisions. Default false.
      #         :sort - sort specification
      #         :from - how many results to skip
      #         :size - how many results to show
      #
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

      # Public: Set or retrieve the ittem type in elasticsearch
      def item_type_name(val = nil)
        @item_type_name = val if val
        @item_type_name || 'content_item'
      end

      # Public: Set or retrieve the index name in elasticsearch
      def index_name(val = nil)
        @index_name = val if val
        @index_name || 'colonel-content'
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
        @es_client ||= ::Elasticsearch::Client.new(host: Colonel.config.elasticsearch_host, log: false)
      end

      # Internal: Revision type name for elastic search.
      def revision_type_name
        item_type_name + "_rev"
      end

      # Public: idempotently create the ES index
      def ensure_index!
        unless es_client.indices.exists index: index_name
          body = { mappings: {} }
          body[:mappings][item_type_name] = item_mapping
          body[:mappings][revision_type_name] = revision_mapping

          es_client.indices.create index: index_name, body: body
        end
      end

      # Public: update the mappings for item and revision types.
      def put_mapping!
        item_body = {
          item_type_name => item_mapping
        }

        revision_body = {
          revision_type_name=> revision_mapping
        }

        es_client.indices.put_mapping index: index_name, type: item_type_name, body: item_body
        es_client.indices.put_mapping index: index_name, type: revision_type_name, body: revision_body
      end

      private

      # Internal: Walk through elasticsearch hits and turn them into ContentItem instances
      def hydrate_hits(hits)
        hits["hits"] = hits["hits"].map do |hit|
          open(hit["_source"]["id"], hit["_source"]["revision"])
        end

        # FIXME this should probably be a result set class with Enumerable mixin
        {total: hits["total"], hits: hits["hits"]}
      end

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
