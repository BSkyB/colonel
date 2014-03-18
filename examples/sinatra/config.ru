require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'])

require './colonel_sample'
run ColonelSample
