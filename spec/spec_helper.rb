$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'active_support'
require 'active_support/deprecation'
require 'active_support/core_ext/module'
require 'active_support/logger'
require 'active_support/tagged_logging'
require 'yaml'
require 'act-fluent-logger-rails/logger'
