require_relative 'support/rails_app'

FLUENTD = boot_rails_app(flush_immediately: true)

describe 'logging from a Rails app with flush_immediately' do
  it 'sends each message of a request in its own record with the log_tags' do
    records = records_from { get('/') }

    expect(records.size).to be >= 4
    expect(records).to all(include(request_tags))
    expect(records.map { |record| record['request_id'] }.uniq.size).to eq(1)
    expect(records.first['messages'].first).to start_with('Started GET "/" for 192.0.2.1')
    expect(records.map { |record| record['messages'] }).to include(['in the controller'])
    expect(records.last['messages'].first).to start_with('Completed 200 OK')
  end

  it 'sends a tag set at run time only with the next message' do
    records = records_from { get('/runtime_tag?uid=user_1') }

    tagged = records.select { |record| record.key?('uid') }
    expect(tagged.map { |record| record['messages'] }).to eq([['set uid']])
  end

  it "doesn't send the log_tags with messages logged after the request" do
    records = records_from do
      get('/')
      Rails.logger.info('outside of a request')
    end

    expect(records.last['messages']).to eq(['outside of a request'])
    expect(records.last.keys).to contain_exactly('messages', 'severity')
  end
end
