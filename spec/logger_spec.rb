require 'spec_helper'
require 'tempfile'


describe ActFluentLoggerRails::Logger do
  before do
    Rails = double("Rails") unless self.class.const_defined?(:Rails)
    Rails.stub(env: "test")
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

  let(:request) {
    double('request', uuid: 'uuid_value', foo: 'foo_value')
  }

  describe 'logging' do

    describe 'basic' do
      it 'info' do
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
    end

    describe 'frozen ascii-8bit string' do
      before do
        logger.instance_variable_set(:@messages_type, :string)
      end

      after do
        logger.instance_variable_set(:@messages_type, :array)
      end

      it 'join messages' do
        ascii = "\xe8\x8a\xb1".force_encoding('ascii-8bit').freeze
        logger.tagged([request]) {
          logger.info(ascii)
          logger.info('咲く')
        }
        expect(@my_logger.log[0][1][:messages]).to eq("花\n咲く")
        expect(ascii.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    describe 'Exception' do
      it 'output message, class, backtrace' do
        begin
          3 / 0
        rescue => e
          logger.tagged([request]) {
            logger.error(e)
          }
          expect(@my_logger.log[0][1][:messages][0]).
            to match(%r|divided by 0 \(ZeroDivisionError\).*spec/logger_spec\.rb:|m)
        end
      end
    end

    describe 'Object' do
      it 'output inspect' do
        x = Object.new
        logger.tagged([request]) {
          logger.info(x)
        }
        expect(@my_logger.log[0][1][:messages][0]).to eq(x.inspect)
      end
    end
  end

  describe "use ENV['FLUENTD_URL']" do
    let(:fluentd_url) { "http://fluentd.example.com:42442/hoge?messages_type=string" }

    describe ".parse_url" do
      subject { described_class.parse_url(fluentd_url) }
      it { expect(subject['tag']).to eq 'hoge' }
      it { expect(subject['fluent_host']).to eq 'fluentd.example.com' }
      it { expect(subject['fluent_port']).to eq 42442 }
      it { expect(subject['messages_type']).to eq 'string' }
    end
  end

  describe 'flush_immediately' do
    describe 'flush_immediately: true' do
      it 'flushed' do
        logger = ActFluentLoggerRails::Logger.new(config_file: File.new(@config_file.path),
                                                  flush_immediately: true)
        logger.info('Immediately!')
        expect(@my_logger.log[0][1][:messages][0]).to eq('Immediately!')
      end
    end

    describe 'flush_immediately: false' do
      it 'flushed' do
        logger = ActFluentLoggerRails::Logger.new(config_file: File.new(@config_file.path),
                                                  flush_immediately: false)
        logger.info('Immediately!')
        expect(@my_logger.log).to eq(nil)
      end
    end
  end
end
