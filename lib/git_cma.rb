require "rugged"
require 'elasticsearch'
require "git_cma/version"

require "git_cma/document"
require "git_cma/content"
require "git_cma/content_item"

module GitCma
  # Public: Sets configuration options.
  #
  # GitCma.config.storage_path - location to store git repo on disk
  # GitCma.config.elasticsearch_host - host for elasticsearch
  #
  # Returns a config struct
  def self.config
    @config ||= Struct.new(:storage_path, :elasticsearch_host).new('storage', 'localhost:9200')
  end
end
