# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rubyhave/version'

Gem::Specification.new do |gem|
  gem.name          = "rubyhave"
  gem.version       = Rubyhave::VERSION
  gem.authors       = ["jsonperl"]
  gem.email         = ["jason.a.pearl@gmail.com"]
  gem.description   = "Ruby behavior tree library"
  gem.summary       = "Rubyhave allows for simple AI behavior definition and execution."
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
