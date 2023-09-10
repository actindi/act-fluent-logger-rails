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
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec", '~> 3.5.0'
  gem.add_runtime_dependency "fluent-logger"
  gem.add_runtime_dependency "railties", ">= 4"
  gem.add_runtime_dependency "activesupport", ">= 4"
end
