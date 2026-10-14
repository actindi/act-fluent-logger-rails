require_relative 'support/rails_app'

FLUENTD = boot_rails_app

describe 'logging from a Rails app' do
  it 'sends the messages of a request in one record with the log_tags' do
    response = nil
    records = records_from { response = get('/') }

    expect(records.size).to eq(1)
    record = records.first
    expect(record).to include(request_tags)
    expect(record['request_id']).to eq(response['X-Request-Id'])
    expect(record['severity']).to eq('INFO')
    expect(record['messages'].first).to start_with('Started GET "/" for 192.0.2.1')
    expect(record['messages']).to include('Processing by WelcomeController#index as HTML', 'in the controller')
    expect(record['messages'].last).to start_with('Completed 200 OK')
  end

  it "doesn't send a request's tags with the next request" do
    records = records_from do
      get('/runtime_tag?uid=user_1')
      get('/')
    end

    expect(records.size).to eq(2)
    expect(records[0]).to include('uid' => 'user_1')
    expect(records[1]).not_to include('uid')
    expect(records[1]['request_id']).not_to eq(records[0]['request_id'])
  end

  it 'sends messages logged outside of a request without the log_tags' do
    records = records_from do
      get('/')
      Rails.logger.info('outside of a request')
      Rails.logger.flush
    end

    expect(records.last['messages']).to eq(['outside of a request'])
    expect(records.last.keys).to contain_exactly('messages', 'severity')
  end

  it 'sends messages in other encodings to fluentd as UTF-8 text' do
    records = records_from do
      Rails.logger.info('日本'.encode('Shift_JIS'))
      Rails.logger.info('花'.b)
      Rails.logger.flush
    end

    expect(records.last['messages']).to eq(['日本', '花'])
    expect(records.last['messages'].map(&:encoding)).to all(eq(Encoding::UTF_8))
  end

  it 'drops messages inside silence' do
    records = records_from { get('/silenced') }

    expect(records.first['messages']).to include('not silenced')
    expect(records.first['messages']).not_to include('silenced')
  end
end
