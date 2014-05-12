require "rugged"
require 'elasticsearch'
require "colonel/version"

require "colonel/document"
require "colonel/document_index"
require "colonel/content"
require "colonel/content_item"

require "colonel/serializer"

module Colonel
  # Public: Sets configuration options.
  #
  # Colonel.config.storage_path       - location to store git repo on disk
  # Colonel.config.index_name         - the name of elasticsearch index to store into
  # Colonel.config.elasticsearch_uri  - host for elasticsearch
  # Colonel.config.rugged_backend     - storage backend, an instance of Rugged::Backend
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :index_name, :elasticsearch_uri, :rugged_backend).new('storage', 'colonel-storage', 'localhost:9200', nil)
  end
end
