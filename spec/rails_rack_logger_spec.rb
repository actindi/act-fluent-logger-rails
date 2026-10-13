require 'spec_helper'
require 'rack/mock'
require 'action_dispatch'
require 'rails/rack/logger'

# Runs a request through the Rails::Rack::Logger of the Rails version under test.
# Rails 7.0 calls `tagged(tags)`, 7.1 calls `tagged(*tags)`, and 7.2+ calls `push_tags(*tags)`,
# then `pop_tags` and `ActiveSupport::LogSubscriber.flush_all!`.
describe Rails::Rack::Logger do
  let(:posted) { [] }

  let(:log_tags) do
    {
      uuid: ->(_request) { 'uuid_value' },
      roles: ->(_request) { ['admin', 'staff'] },
      ip: :ip,
    }
  end

  let(:logger) do
    ActFluentLoggerRails::Logger.new(config_file: nil, settings: { tag: 'foo' }, log_tags: log_tags)
  end

  before do
    allow(Rails).to receive(:env).and_return('test')
    allow(Rails).to receive_message_chain(:application, :config, :log_level).and_return(:debug)
    allow(Rails).to receive_message_chain(:application, :config, :log_tags=)

    posted = self.posted
    fluent_logger = Object.new
    fluent_logger.define_singleton_method(:post) { |_tag, map| posted << map.merge(messages: map[:messages].dup) }
    allow(Fluent::Logger::FluentLogger).to receive(:new).and_return(fluent_logger)

    # Rails 7.1+ wraps config.logger in a BroadcastLogger
    rails_logger = defined?(ActiveSupport::BroadcastLogger) ? ActiveSupport::BroadcastLogger.new(logger) : logger
    allow(Rails).to receive(:logger).and_return(rails_logger)
    allow(ActiveSupport::LogSubscriber).to receive(:logger).and_return(rails_logger)
  end

  it 'sends the log_tags with the messages of the request' do
    app = lambda do |_env|
      Rails.logger.info('hello')
      [200, {}, ['ok']]
    end
    middleware = described_class.new(app, log_tags.values)

    _status, _headers, body = middleware.call(Rack::MockRequest.env_for('/', 'REMOTE_ADDR' => '192.0.2.1'))
    body.close

    expect(posted.size).to eq(1)
    expect(posted.first).to include(uuid: 'uuid_value', roles: ['admin', 'staff'], ip: '192.0.2.1')
    expect(posted.first[:messages]).to include('hello')
  end

  context 'when the only log tag has an Array value' do
    let(:log_tags) { { roles: ->(_request) { ['admin', 'staff'] } } }

    it 'sends the Array as the value of the tag' do
      middleware = described_class.new(->(_env) { [200, {}, ['ok']] }, log_tags.values)

      _status, _headers, body = middleware.call(Rack::MockRequest.env_for('/'))
      body.close

      expect(posted.first).to include(roles: ['admin', 'staff'])
    end
  end
end
