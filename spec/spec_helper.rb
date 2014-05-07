require 'rubygems'
require 'bundler/setup'

require 'simplecov'

if ENV['CIRCLE_ARTIFACTS']
  dir = File.join("..", "..", "..", ENV['CIRCLE_ARTIFACTS'], "coverage")
  SimpleCov.start do
    coverage_dir(dir)
    add_filter "/vendor/"
  end
else
  SimpleCov.start
end

require 'pry'

require 'colonel'
include Colonel

RSpec.configure do |config|
  config.mock_with :rspec
  config.filter_run_excluding live: true unless ENV['ALL']
  config.raise_errors_for_deprecations!
end
