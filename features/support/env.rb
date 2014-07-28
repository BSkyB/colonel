require "pry"
require "fileutils"
require "simplecov"

if ENV['CIRCLE_ARTIFACTS']
  dir = File.join("..", "..", "..", ENV['CIRCLE_ARTIFACTS'], "coverage")
  SimpleCov.start do
    coverage_dir(dir)
    add_filter "/spec/"
    add_filter "/features/"

    add_filter "/vendor/"
  end
else
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/features/"
  end
end

require "colonel"

include Colonel

Colonel.config.index_name = 'colonel-test'

begin
  ElasticsearchProvider.es_client.indices.delete index: Colonel.config.index_name
  FileUtils.rm_rf Colonel.config.storage_path
rescue
end

ElasticsearchProvider.initialize!

Before do
  ElasticsearchProvider.es_client.delete_by_query index: Colonel.config.index_name, q: '*'
  FileUtils.rm_rf Colonel.config.storage_path
end
