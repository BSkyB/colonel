require "rugged"
require 'elasticsearch'
require "colonel/version"

require "colonel/document"
require "colonel/content"
require "colonel/content_item"

module Colonel
  # Public: Sets configuration options.
  #
  # Colonel.config.storage_path - location to store git repo on disk
  # Colonel.config.elasticsearch_host - host for elasticsearch
  # Colonel.config.rugged_backend - storage backend, an instance of Rugged::Backend
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :elasticsearch_host, :rugged_backend).new('storage', 'localhost:9200', nil)
  end
end
