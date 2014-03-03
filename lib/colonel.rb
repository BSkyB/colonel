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
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :elasticsearch_host, :redis_host).new('storage', 'localhost:9200', 'localhost:6379')
  end
end
