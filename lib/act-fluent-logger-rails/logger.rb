require 'fluent-logger'
require 'active_support/core_ext'
require 'uri'
require 'cgi'

module ActFluentLoggerRails

  module Logger

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

    def self.new(config_file: Rails.root.join("config", "fluent-logger.yml"),
                 log_tags: {},
                 settings: {},
                 flush_immediately: false)
      Rails.application.config.log_tags = log_tags.values
      if Rails.application.config.respond_to?(:action_cable)
        Rails.application.config.action_cable.log_tags = log_tags.values.map do |x|
          case
          when x.respond_to?(:call)
            x
          when x.is_a?(Symbol)
            -> (request) { request.send(x) }
          else
            -> (request) { x }
          end
        end
      end
      if (0 == settings.length)
        fluent_config = if ENV["FLUENTD_URL"]
                          self.parse_url(ENV["FLUENTD_URL"])
                        else
                          YAML.load(ERB.new(config_file.read).result)[Rails.env]
                        end
        settings = {
          tag:  fluent_config['tag'],
          host: fluent_config['fluent_host'],
          port: fluent_config['fluent_port'],
          messages_type: fluent_config['messages_type'],
          severity_key: fluent_config['severity_key'],
        }
      end

      settings[:flush_immediately] ||= flush_immediately

      level = SEV_LABEL.index(Rails.application.config.log_level.to_s.upcase)
      logger = ActFluentLoggerRails::FluentLogger.new(settings, level, log_tags)
      logger = ActiveSupport::TaggedLogging.new(logger)
      logger.extend self
    end

    def self.parse_url(fluentd_url)
      uri = URI.parse fluentd_url
      params = CGI.parse uri.query

      {
        fluent_host: uri.host,
        fluent_port: uri.port,
        tag: uri.path[1..-1],
        messages_type: params['messages_type'].try(:first),
        severity_key: params['severity_key'].try(:first),
      }.stringify_keys
    end

    def tagged(*tags)
      @tags = tags.flatten
      yield self
    ensure
      flush
    end
  end

  class FluentLogger < (ActiveSupport.version.to_s > '4' ? ActiveSupport::Logger : ActiveSupport::BufferedLogger)
    def initialize(options, level, log_tags)
      self.level = level
      port    = options[:port]
      host    = options[:host]
      @messages_type = (options[:messages_type] || :array).to_sym
      @tag = options[:tag]
      @severity_key = (options[:severity_key] || :severity).to_sym
      @flush_immediately = options[:flush_immediately]
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(nil, host: host, port: port)
      @severity = 0
      @messages = []
      @log_tags = log_tags
      @map = {}
      after_initialize if respond_to? :after_initialize
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < level
      message = (block_given? ? block.call : progname) if message.blank?
      return true if message.blank?
      add_message(severity, message)
      true
    end

    def add_message(severity, message)
      @severity = severity if @severity < severity

      message =
        case message
        when ::String
          message
        when ::Exception
          "#{ message.message } (#{ message.class })\n" <<
            (message.backtrace || []).join("\n")
        else
          message.inspect
        end

      if message.encoding == Encoding::UTF_8
        @messages << message
      else
        @messages << message.dup.force_encoding(Encoding::UTF_8)
      end

      flush if @flush_immediately
    end

    def [](key)
      @map[key]
    end

    def []=(key, value)
      @map[key] = value
    end

    def flush
      return if @messages.empty?
      messages = if @messages_type == :string
                   @messages.join("\n")
                 else
                   @messages
                 end
      @map[:messages] = messages
      @map[@severity_key] = format_severity(@severity)
      if @tags
        @log_tags.keys.zip(@tags).each do |k, v|
          @map[k] = v
        end
      end
      @fluent_logger.post(@tag, @map)
      @severity = 0
      @messages.clear
      @tags = nil
      @map.clear
    end

    def close
      @fluent_logger.close
    end

    def level
      @level
    end

    def level=(l)
      @level = l
    end

    def format_severity(severity)
      ActFluentLoggerRails::Logger::SEV_LABEL[severity] || 'ANY'
    end
  end
end
