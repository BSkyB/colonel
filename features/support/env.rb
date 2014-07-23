require "colonel"
require "pry"

include Colonel

ElasticsearchProvider.initialize!(Colonel::Document)

at_exit do
  ElasticsearchProvider.es_client.indices.delete index: Colonel.config.index_name
end
