# A minimal Rails app that uses the logger the way the README describes, so the specs go
# through the real middleware stack, controller log subscribers and BroadcastLogger.
# A Rails app can only boot once per process, so each spec file in spec/integration
# boots it with its own logger options and runs in a separate process (see the Rakefile).
ENV['RAILS_ENV'] = 'test'

require 'logger'
require 'rails'
require 'action_controller/railtie'
require 'rack/mock'
require 'act-fluent-logger-rails'
require_relative 'fake_fluentd'

class IntegrationApp < Rails::Application
  config.root = File.expand_path('..', __dir__)
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.log_level = :debug
  config.secret_key_base = 'integration' * 8
end

class WelcomeController < ActionController::Base
  def index
    logger.info('in the controller')
    render plain: 'ok'
  end

  def runtime_tag
    logger[:uid] = params[:uid]
    logger.info('set uid')
    render plain: 'ok'
  end

  def silenced
    logger.silence { logger.info('silenced') }
    logger.info('not silenced')
    render plain: 'ok'
  end
end

LOG_TAGS = {
  request_id: :request_id,
  ip: :ip,
  ua: :user_agent,
  roles: ->(_request) { ['admin', 'staff'] },
}.freeze

FLUENTD = FakeFluentd.new

def boot_rails_app(**logger_options)
  ENV['FAKE_FLUENTD_PORT'] = FLUENTD.port.to_s
  IntegrationApp.configure do
    config.logger = ActFluentLoggerRails::Logger.new(log_tags: LOG_TAGS, **logger_options)
  end
  IntegrationApp.initialize!
  IntegrationApp.routes.draw do
    get '/' => 'welcome#index'
    get '/runtime_tag' => 'welcome#runtime_tag'
    get '/silenced' => 'welcome#silenced'
  end
end

module IntegrationHelpers
  END_MARKER = 'end of records'

  def get(path, headers = {})
    Rack::MockRequest.new(Rails.application).get(path, { 'REMOTE_ADDR' => '192.0.2.1', 'HTTP_USER_AGENT' => 'RSpec' }.merge(headers))
  end

  # The records fluentd received while running the block. Logs and flushes a marker
  # outside of any request afterwards, so it knows when it has all of them.
  def records_from
    yield
    Rails.logger.info(END_MARKER)
    Rails.logger.flush
    FLUENTD.take_until { |record| Array(record['messages']).include?(END_MARKER) }
  end

  def request_tags
    { 'ip' => '192.0.2.1', 'ua' => 'RSpec', 'roles' => ['admin', 'staff'] }
  end
end

RSpec.configure do |config|
  config.include IntegrationHelpers
end
