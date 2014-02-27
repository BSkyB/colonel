require 'rubygems'
require 'bundler/setup'

require 'simplecov'

if ENV['CIRCLE_ARTIFACTS']
  dir = File.join("..", "..", "..", ENV['CIRCLE_ARTIFACTS'], "coverage")
  SimpleCov.start do
    coverage_dir(dir)
  end
else
  SimpleCov.start
end

require 'git_cma'
include GitCma

RSpec.configure do |config|
  config.mock_with :rspec
end
