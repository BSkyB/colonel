module Colonel
  class Indexer
    class << self

      # Public: Index the documents in elasticsearch using type_to_citems as mapping from types to
      # content item classes. Uses elasticsearch bulk API to index each document.
      #
      # documents       - array of document instances to (re)index
      #
      # returns nothing
      def index(documents, index_name = nil)
        ElasticsearchProvider.initialize!

        documents.each do |document|
          cmds = document_commands(document, index_name)

          ElasticsearchProvider.es_client.bulk body: cmds
        end
      end

      # Internal: get index commands for elasticsearch for a single document instance
      def document_commands(document, index_name = nil)
        type = document.type

        rev_indexes = []
        state_indexes = {}
        custom_indexes = {}

        document.repository.references.each do |ref|
          state = ref.name.split("/").last
          next if state == "root"

          document.history(state).each do |r|
            event = {
              name: r.type,
              to: state
            }

            sp = type.search_provider
            cmds = sp.index_commands(document, r, state, event)

            # add or update the index commands for documents
            cmds.each do |cmd|
              case cmd[:index][:_type]
              when sp.revision_type_name

                rev_indexes << cmd
              when sp.type_name
                updated_at =  Time.parse(cmd[:index][:data][:updated_at])
                state_updated_at = Time.parse(state_indexes[state][:index][:data][:updated_at]) if state_indexes[state]

                state_indexes[state] = cmd if state_updated_at.nil? || updated_at > state_updated_at
              else
                updated_at =  Time.parse(cmd[:index][:data][:updated_at])
                name = cmd[:index][:_type]
                custom_updated_at = Time.parse(custom_indexes[name][:index][:data][:updated_at]) if custom_indexes[name]

                custom_indexes[name] = cmd if custom_updated_at.nil? || updated_at > custom_updated_at
              end

              # override the index, if requested
              cmd[:index][:_index] = index_name if index_name
            end
          end
        end

        # return all the commands together
        rev_indexes + state_indexes.values + custom_indexes.values
      end
    end
  end
end
