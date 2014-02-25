require "rugged"
require 'elasticsearch'
require "git_cma/version"

require "git_cma/document"
require "git_cma/content"
require "git_cma/content_item"

module GitCma
  def config
    @config ||= Struct.new(:storage_path).new('storage')
  end
end
