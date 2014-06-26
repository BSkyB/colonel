module Colonel
  class Indexer
    class << self

      # Public: Index the documents in elasticsearch using type_to_citems as mapping from types to
      # content item classes. Uses elasticsearch bulk API to index each document.
      #
      # documents       - array of document instances to (re)index
      # types_to_citems - hash mapping from type names to content item classes
      #                   (e.g. {'content_item' => Colonel::ContentItem})
      #
      # returns nothing
      def index(documents, types_to_citems)
        put_mappings(types_to_citems.values)

        documents.each do |document|
          es_client.bulk body: document_commands(document, types_to_citems)
        end
      end

      # Internal: get index commands for elasticsearch for a single document instance
      def document_commands(document, types_to_citems)
        repo = document.repository

        klass = types_to_citems[document.type]
        raise "Missing class for type #{type}" unless klass

        rev_indexes = []
        state_indexes = {}
        custom_indexes = {}

        content_item = klass.open(document.name)

        repo.references.each do |ref|
          state = ref.name.split("/").last
          next if state == "root"

          content_item.load!(state)

          content_item.history.each do |r|
            sha = r[:rev]
            date = r[:time]

            event = {
              name: r[:type],
              to: state
            }

            # get index commands
            content_item.load!(sha)
            cmds = content_item.index_commands(state: state, revision: sha, updated_at: date, event: event)

            # add or update the index commands for documents
            cmds.each do |cmd|
              case cmd[:index][:_type]
              when klass.revision_type_name

                rev_indexes << cmd
              when klass.item_type_name
                updated_at =  Time.parse(cmd[:index][:data][:updated_at])
                state_updated_at = Time.parse(state_indexes[state][:index][:data][:updated_at]) if state_indexes[state]

                state_indexes[state] = cmd if state_updated_at.nil? || updated_at > state_updated_at
              else
                updated_at =  Time.parse(cmd[:index][:data][:updated_at])
                name = cmd[:index][:_index]
                custom_updated_at = Time.parse(state_indexes[name][:index][:data][:updated_at]) if custom_indexes[name]

                latest_index = cmd if custom_updated_at.nil? || updated_at > custom_updated_at
              end
            end
          end
        end

        # return all the commands together
        rev_indexes + state_indexes.values + custom_indexes.values
      end

      private

      def es_client
        @es_client ||= ::Elasticsearch::Client.new(host: Colonel.config.elasticsearch_uri, log: false)
      end

      def put_mappings(klasses)
        klasses.each do |klass|
          klass.ensure_index!
          klass.put_mapping!
        end
      end
    end
  end
end
