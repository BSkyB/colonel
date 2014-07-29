
module Colonel
  # Public: Elasticsearch provider for documents. This handles all the indexing and searching using
  # Elasticsearch. Documents are indexed on each `save` or `promote!` call.
  #
  # Each DocumentType has it's own instance of ElasticsearchProvider with a configuration for the
  # type (index_name, type_name, attributes_mapping and scopes).
  #
  # You can initialize the search support by calling `ElasticsearchProvider.initialize!` *after*
  # defining all your types.
  #
  # If you need to, you can run raw elasticsearch queries using `ElasticsearchProvider.es_client`
  class ElasticsearchProvider

    attr_reader :index_name, :type_name, :item_mapping, :revision_mapping, :scopes

    def initialize(index_name, type_name, custom_mapping = nil, scopes = nil)
      @index_name = (index_name || Colonel.config.index_name).to_s
      @type_name = type_name.to_s

      @item_mapping = self.class.default_item_mapping
      @item_mapping[:properties] = @item_mapping[:properties].merge(custom_mapping) if custom_mapping

      @revision_mapping = self.class.default_revision_mapping(@type_name)
      @revision_mapping[:properties] = @revision_mapping[:properties].merge(custom_mapping) if custom_mapping

      @scopes = scopes || []
    end

    def revision_type_name
      "#{type_name}_rev"
    end

    # Public: List all the content items. Supports filtering by state, sorting and pagination.
    #
    # opts  - options hash
    #         :state  - state to filter to
    #         :scope  - filter search to a custom scope
    #         :sort   - sort specification for ES. ex.: {updated_at: 'desc'} or [{...}, {...}].
    #                   Wrapped in an array automatically.
    #         :from   - how many results to skip
    #         :size   - how many results to return
    #
    # Returns the elasticsearch result set
    def list(opts = {})
      state = opts[:state] || 'master'

      query = { query: { constant_score: { filter: { term: { state: state } }}}}

      search(query, opts)
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
    def search(query, opts = {})
      query = { query: { query_string: { query: query }} } if query.is_a?(String)
      query = { query: { has_child: { type: revision_type_name.to_s }.merge(query) } } if opts[:history]

      body = query

      body[:from] = opts[:from] if opts[:from]
      body[:size] = opts[:size] if opts[:size]

      body[:sort] = opts[:sort] if opts[:sort]
      body[:sort] = [body[:sort]] if body[:sort] && !body[:sort].is_a?(Array)

      if opts[:scope]
        item_type = "#{type_name.to_s}_#{opts[:scope]}"
      else
        item_type = "#{type_name.to_s}"
      end

      res = es_client.search(index: index_name, type: item_type, body: body)

      ElasticsearchResultSet.new(res)
    end

    # Public: Index the content in elasticsearch. Creates a document for the revision and updates the document
    # for the item, to enable both search of the lates and all the revisions.
    # Document ids have a format docid-state and docid-revisionsha.
    #
    # Returns nothing
    def index!(document, revision, state, event)
      commands = index_commands(document, revision, state, event)
      es_client.bulk body: commands
    end

    # Internal: build the index commands for `index!` without running them against es_client
    def index_commands(document, revision, state = 'master', event = 'save')
      body = {
        id: document.id,
        revision: revision.id,
        state: state,
        updated_at: revision.timestamp.iso8601
      }

      body = body.merge(revision.content.plain)

      latest_id = "#{document.id}"
      item_id = "#{document.id}-#{state}"
      rev_id = "#{document.id}-#{revision.id}"

      cmds = [
        {index: {_index: index_name, _type: type_name, _id: item_id, data: body}},
        {index: {_index: index_name, _type: revision_type_name, _id: rev_id, _parent: item_id, data: body}}
      ]

      scopes.each do |scope, pred|
        on = [pred[:on]].flatten.map(&:to_sym)
        to = [pred[:to]].flatten.map(&:to_sym)
        next unless on.any? { |o| o.to_sym == event[:name].to_sym } && to.any? { |t| t == event[:to].to_sym }

        name = "#{type_name}_#{scope}"
        cmds << {index: {_index: index_name, _type: name, _id: latest_id, data: body}}
      end

      cmds
    end

    # Public: The Elasticsearch client
    def es_client
      self.class.es_client
    end

    class << self
      # Public: Initialize search index for all Document subclasses. Creates an index for each
      # class respecting the type, index name and attributes mapping specified by each class
      def initialize!
        # for all specified classes
        DocumentType.all.each do |type_name, type|
          sp = type.search_provider
          next unless sp

          # ensure index existence and update mapping
          ensure_index!(sp.index_name, sp.type_name, sp.revision_type_name, sp.item_mapping, sp.revision_mapping, sp.scopes)
          put_mapping!(sp.index_name, sp.type_name, sp.revision_type_name, sp.item_mapping, sp.revision_mapping, sp.scopes)
        end
      end

      # Public: The Elasticsearch client
      def es_client
        @es_client ||= ::Elasticsearch::Client.new(host: Colonel.config.elasticsearch_uri, log: false)
      end

      # Internal: idempotently create the ES index
      def ensure_index!(index_name, type_name, revision_type_name, item_mapping, revision_mapping, scopes)
        unless es_client.indices.exists index: index_name
          body = { mappings: {} }
          body[:mappings][type_name] = item_mapping
          body[:mappings][revision_type_name] = revision_mapping

          scopes.each do |name, preds|
            name = "#{type_name}_#{name}"
            body[:mappings][name] = item_mapping
          end

          es_client.indices.create index: index_name, body: body
        end
      end

      # Internal: update the mappings for item and revision types.
      def put_mapping!(index_name, type_name, revision_type_name, item_mapping, revision_mapping, scopes)
        item_body = {
          type_name => item_mapping
        }
        revision_body = {
          revision_type_name=> revision_mapping
        }

        es_client.indices.put_mapping index: index_name, type: type_name, body: item_body
        es_client.indices.put_mapping index: index_name, type: revision_type_name, body: revision_body

        scopes.each do |name, preds|
          name = "#{type_name}_#{name}"
          body = {name => item_mapping}

          es_client.indices.put_mapping index: index_name, type: name, body: body
        end
      end

      # Internal: Default revision mapping, used for all search in history
      def default_revision_mapping(type_name)
        {
          _source: { enabled: false }, # you only get what you store
          _parent: { type: type_name },
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
