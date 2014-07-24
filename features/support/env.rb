require "colonel"
require "pry"

include Colonel

Colonel.config.index_name = 'colonel-test'

begin
  ElasticsearchProvider.es_client.indices.delete index: Colonel.config.index_name
rescue
end

ElasticsearchProvider.initialize!(Colonel::Document)

Before do
  ElasticsearchProvider.es_client.delete_by_query index: Colonel.config.index_name, q: '*'
end
