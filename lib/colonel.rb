require "rugged"
require 'elasticsearch'
require "colonel/version"

require "colonel/document"
require "colonel/content"
require "colonel/content_item"

module Colonel
  # Public: Sets configuration options.
  #
  # GitCma.config.storage_path - location to store git repo on disk
  # GitCma.config.elasticsearch_uri - uri for elasticsearch
  # GitCma.config.redis_host - redis host
  # GitCma.config.redis_port - redis port
  # GitCma.config.redis_password - redis password if required
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :elasticsearch_uri, :redis_host, :redis_port, :redis_password).new('storage', 'localhost:9200', 'localhost', 6379, '')
  end
end
