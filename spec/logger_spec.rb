require 'spec_helper'
require 'tempfile'


describe ActFluentLoggerRails::Logger do
  before do

    Rails = double("Rails", env: "test")
    Rails.stub_chain(:application, :config, :log_level).and_return(:debug)
    Rails.stub_chain(:application, :config, :log_tags=)

    class MyLogger
      attr_accessor :log
      def post(tag, map)
        @log ||= []
        @log << [tag, map.merge(messages: map[:messages].dup)]
      end
      def clear
        @log.clear
      end
      def close
      end
    end
    @my_logger = MyLogger.new
    Fluent::Logger::FluentLogger.stub(:new) { @my_logger }

    @config_file = Tempfile.new('fluent-logger-config')
    @config_file.close(false)
    File.open(@config_file.path, 'w') {|f|
      f.puts <<EOF
test:
  fluent_host: '127.0.0.1'
  fluent_port: 24224
  tag:         'foo'
EOF
    }
  end

  let(:logger) {
    ActFluentLoggerRails::Logger.new(config_file: File.new(@config_file.path),
                                     log_tags: {
                                       uuid: :uuid,
                                       foo: ->(request) { request.foo }
                                     })
  }

  it 'info' do
    request = double('request', uuid: 'uuid_value', foo: 'foo_value')
    logger[:abc] = 'xyz'
    logger.tagged([request]) { logger.info('hello') }
    expect(@my_logger.log).to eq([['foo', {
                                     abc: 'xyz',
                                     messages: ['hello'],
                                     level: 'INFO',
                                     uuid: 'uuid_value',
                                     foo: 'foo_value'
                                   } ]])
    @my_logger.clear
    logger.tagged([request]) { logger.info('world'); logger.info('bye') }
    expect(@my_logger.log).to eq([['foo', {
                                     messages: ['world', 'bye'],
                                     level: 'INFO',
                                     uuid: 'uuid_value',
                                     foo: 'foo_value'
                                   } ]])
  end

  describe "use ENV['FLUENTD_URL']" do
    let(:fluentd_url) { "http://fluentd.example.com:42442/hoge?messages_type=string" }

    describe ".parse_url" do
      subject { described_class.parse_url(fluentd_url) }
      it { expect(subject['tag']).to eq 'hoge' }
      it { expect(subject['host']).to eq 'fluentd.example.com' }
      it { expect(subject['port']).to eq 42442 }
      it { expect(subject['messages_type']).to eq 'string' }
    end
  end
end
