require 'rubygems'
require 'bundler/setup'

require 'git_cma'
include GitCma

RSpec.configure do |config|
  config.mock_with :rspec
end
