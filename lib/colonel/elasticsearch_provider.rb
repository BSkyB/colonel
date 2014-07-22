
module Colonel
  class ElasticsearchProvider

    attr_reader :index_name, :type_name

    def initialize(index_name, type_name)
      @index_name = index_name.to_s
      @type_name = type_name.to_s
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
    def list(type_name, opts = {})
      state = opts[:state] || 'master'

      query = { query: { constant_score: { filter: { term: { state: state } }}}}

      query[:from] = opts[:from] if opts[:from]
      query[:size] = opts[:size] if opts[:size]

      query[:sort] = opts[:sort] if opts[:sort]
      query[:sort] = [query[:sort]] if query[:sort] && !query[:sort].is_a?(Array)

      if opts[:scope]
        item_type = "#{type_name.to_s}_#{opts[:scope]}"
      else
        item_type = "#{type_name.to_s}"
      end

      res = es_client.search(index: index_name, type: item_type, body: query)

      ElasticsearchResultSet.new(res)
    end

    # Public: Index the content in elasticsearch. Creates a document for the revision and updates the document
    # for the item, to enable both search of the lates and all the revisions.
    # Document ids have a format docid-state and docid-revisionsha.
    #
    # opts - an options hash with keys
    #        :state - the state of the document
    #        :updated_at - the timestamp
    #        :revision - the sha of the revision
    #        :event - the event causing the index - object with keys:
    #                 :name - :save or :promote
    #                 :to   - to state name
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

      # TODO scopes
      # self.class.scopes.each do |scope, pred|
      #   on = [pred[:on]].flatten.map(&:to_sym)
      #   to = [pred[:to]].flatten.map(&:to_sym)
      #   next unless on.any? { |o| o.to_sym == event[:name].to_sym } && to.any? { |t| t == event[:to].to_sym }

      #   name = "#{self.class.item_type_name}_#{scope}"
      #   cmds << {index: {_index: self.class.index_name, _type: name, _id: latest_id, data: body}}
      # end

      cmds
    end

    # Public: The Elasticsearch client
    def es_client
      @es_client ||= ::Elasticsearch::Client.new(host: Colonel.config.elasticsearch_uri, log: false)
    end
  end
end
