require 'rails_helper'
require 'rspec/rails'

class Fluent::Logger::FluentLogger
  def pending_data
    @pending
  end
end

RSpec.describe 'ActFluentLoggerRails Middleware', type: :request do
  let(:log_tags) {
    { uuid: :uuid,
      foo: ->(request) { 'foo_value' },
      uid: ->(request) { request.session[:uid] }
    }
  }

  it 'logs session uid' do
    # Make a request to trigger the middleware and logging
    get '/', headers: { 'HTTP_UUID': 'uuid_value', 'HTTP_USER_AGENT': 'Firefox/1.0' }

    fl = Rails.logger.instance_variable_get("@fluent_logger")
    pending_data = fl.pending_data
    decoded_data = MessagePack.unpack(pending_data)[2]

    expect(decoded_data['uuid']).to be_present
    expect(decoded_data['foo']).to eq('foo_value')
    expect(decoded_data['uid']).to eq('123')
    expect(decoded_data['level']).to eq('INFO')
    expect(decoded_data['ua']).to eq('Firefox/1.0')
    expect(decoded_data['messages']).to include('Started GET "/" for 127.0.0.1')
    expect(decoded_data['messages']).to include('Processing by WelcomeController#index as HTML')
  end
end
