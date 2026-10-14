require_relative 'support/rails_app'

FLUENTD = boot_rails_app(fluentd: FakeFluentd.new(unix_socket: true))

describe 'logging from a Rails app to fluentd on a Unix socket' do
  it 'sends the messages of a request in one record with the log_tags' do
    records = records_from { get('/') }

    expect(records.size).to eq(1)
    expect(records.first).to include(request_tags)
    expect(records.first['messages']).to include('in the controller')
  end
end
