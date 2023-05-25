require 'fluent-logger'
require 'active_support/core_ext'
require 'uri'
require 'cgi'
require 'rails/version'

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
          nanosecond_precision: fluent_config['nanosecond_precision'],
          messages_type: fluent_config['messages_type'],
          severity_key: fluent_config['severity_key'],
          tls_options: fluent_config['tls_options']&.transform_keys { |k| k.to_sym }
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
        nanosecond_precision: params['nanosecond_precision'].try(:first),
        messages_type: params['messages_type'].try(:first),
        severity_key: params['severity_key'].try(:first),
      }.stringify_keys
    end

    def tagged(*tags)
      @tags_thread_key ||= "fluentd_tagged_logging_tags:#{object_id}".freeze
      Thread.current[@tags_thread_key] = tags.flatten
      yield self
    ensure
      flush
    end
  end

  class FluentLogger < ActiveSupport::Logger
    def initialize(options, level, log_tags)
      self.level = level
      port    = options[:port]
      host    = options[:host]
      nanosecond_precision = options[:nanosecond_precision]
      @messages_type = (options[:messages_type] || :array).to_sym
      @tag = options[:tag]
      @severity_key = (options[:severity_key] || :severity).to_sym
      @flush_immediately = options[:flush_immediately]
      logger_opts = {host: host, port: port, nanosecond_precision: nanosecond_precision}
      logger_opts[:tls_options] = options[:tls_options] unless options[:tls_options].nil?
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(nil, logger_opts)
      @severity = 0
      @log_tags = log_tags
      after_initialize if respond_to?(:after_initialize) && Rails::VERSION::MAJOR < 6
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
        logger_messages << message
      else
        logger_messages << message.dup.force_encoding(Encoding::UTF_8)
      end

      flush if @flush_immediately
    end

    def [](key)
      map[key]
    end

    def []=(key, value)
      map[key] = value
    end

    def flush
      return if logger_messages.empty?
      messages = if @messages_type == :string
                   logger_messages.join("\n")
                 else
                   logger_messages
                 end
      map[:messages] = messages
      map[@severity_key] = format_severity(@severity)
      add_tags

      @fluent_logger.post(@tag, map)
      @severity = 0
      logger_messages.clear
      Thread.current[@tags_thread_key] = nil if @tags_thread_key
      map.clear
    end

    def add_tags
      return unless @tags_thread_key && Thread.current.key?(@tags_thread_key)

      @log_tags.each do |k, v|
        value = case v
                when Proc
                  v.call(request)
                when Symbol
                  request.send(v) if request.respond_to?(v)
                else
                  v
                end
        map[k] = value
      end
    end

    def logger_messages
      @messages_thread_key ||= "fluentd_logger_messages:#{object_id}".freeze
      Thread.current[@messages_thread_key] ||= []
    end

    def map
      @map_thread_key ||= "fluentd_logger_map:#{object_id}".freeze
      Thread.current[@map_thread_key] ||= {}
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

    def request
      @request_thread_key ||= "fluentd_logger_request:#{object_id}".freeze
      Thread.current[@request_thread_key]
    end

    def request=(req)
      @request_thread_key ||= "fluentd_logger_request:#{object_id}".freeze
      Thread.current[@request_thread_key] = req
    end
  end
end
