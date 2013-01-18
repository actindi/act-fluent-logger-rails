# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'act-fluent-logger-rails/version'

Gem::Specification.new do |gem|
  gem.name          = "act-fluent-logger-rails"
  gem.version       = ActFluentLoggerRails::VERSION
  gem.authors       = ["TAHARA Yoshinori"]
  gem.email         = ["read.eval.print@gmail.com"]
  gem.description   = %q{Fluent logger}
  gem.summary       = %q{Fluent logger}
  gem.homepage      = "https://github.com/actindi/act-fluent-logger-rails"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"
  gem.add_runtime_dependency "fluent-logger"
  gem.add_runtime_dependency "rails"
end
