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
  # Colonel.config.elasticsearch_uri - uri for elasticsearch
  # Colonel.config.redis_host - redis host
  # Colonel.config.redis_port - redis port
  # Colonel.config.redis_password - redis password if required
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :elasticsearch_uri, :redis_host, :redis_port, :redis_password).new('storage', 'localhost:9200', 'localhost', 6379, '')
  end
end
