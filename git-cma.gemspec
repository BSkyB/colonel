# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'git_cma/version'

Gem::Specification.new do |spec|
  spec.name          = "git_cma"
  spec.version       = GitCma::VERSION
  spec.authors       = ["Viktor Charypar"]
  spec.email         = ["viktor.charypar@red-badger.com"]
  spec.summary       = %q{Git-backed document storage with versioning}
  spec.homepage      = ""

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rugged"
  spec.add_runtime_dependency "elasticsearch", "~> 1.0.0"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "shoulda-matchers"
end
