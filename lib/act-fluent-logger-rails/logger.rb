require 'fluent-logger'
# Require only what this file uses. Loading all of active_support/core_ext during
# Bundler.require would preempt app config such as Rails 7.0's disable_to_s_conversion.
require 'logger'
require 'active_support'
require 'active_support/logger'
require 'active_support/tagged_logging'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/keys'
require 'uri'
require 'rails/version'

module ActFluentLoggerRails

  module Logger

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

    def self.new(config_file: Rails.root.join("config", "fluent-logger.yml"),
                 log_tags: {},
                 settings: {},
                 flush_immediately: false)
      # A second logger without log_tags (e.g. one for background jobs) shouldn't clear the app's tags.
      unless log_tags.empty?
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
      # CGI.parse was removed from the default cgi library in Ruby 4.0. Keep the first value of duplicate keys like CGI.parse did.
      params = URI.decode_www_form(uri.query.to_s).each_with_object({}) { |(key, value), h| h[key] ||= value }

      {
        fluent_host: uri.host,
        fluent_port: uri.port,
        tag: uri.path[1..-1],
        nanosecond_precision: params['nanosecond_precision'],
        messages_type: params['messages_type'],
        severity_key: params['severity_key'],
      }.stringify_keys
    end

    # Tags are matched to log_tags keys by position, so don't flatten Array values.
    # Rails 7.0 passes them as one Array, 7.1 as separate arguments.
    def tagged(*tags)
      tags = tags.first if ActFluentLoggerRails::Logger.rails_passes_tags_as_array? && tags.length == 1 && tags.first.is_a?(Array)
      self.request_tags = tags
      yield self
    ensure
      flush
      # With flush_immediately, flush keeps the tags for the next lines of the request.
      self.request_tags = nil
    end

    # Used instead of `tagged` by Rails 7.2+.
    def push_tags(*tags)
      self.request_tags = tags
      tags
    end

    # Keep the tags until flush, which Rails calls right after this.
    # With flush_immediately everything is already sent, so clear them here.
    def pop_tags(count = 1)
      self.request_tags = nil if @flush_immediately
      []
    end

    def self.rails_passes_tags_as_array?
      Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR == 0
    end
  end

  class FluentLogger < ActiveSupport::Logger
    def initialize(options, level, log_tags)
      # No log device: messages go to fluentd in add/flush.
      super(nil, level: level)
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
      @log_tag_keys = log_tags.keys
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
      messages = logger_messages
      return if messages.empty?
      payload = map
      payload[:messages] = @messages_type == :string ? messages.join("\n") : messages
      payload[@severity_key] = format_severity(@severity)
      add_tags(payload)

      @fluent_logger.post(@tag, payload)
      @severity = 0
      messages.clear
      # flush_immediately flushes every line, so keep the tags until the request ends.
      self.request_tags = nil unless @flush_immediately
      payload.clear
    end

    def add_tags(payload)
      tags = request_tags
      return unless tags
      # Index instead of keys.zip(tags) so a flush doesn't allocate an Array per tag.
      @log_tag_keys.each_with_index do |key, i|
        payload[key] = tags[i]
      end
    end

    def request_tags
      @tags_thread_key ||= :"fluentd_tagged_logging_tags:#{object_id}"
      Thread.current[@tags_thread_key]
    end

    def request_tags=(tags)
      @tags_thread_key ||= :"fluentd_tagged_logging_tags:#{object_id}"
      Thread.current[@tags_thread_key] = tags
    end

    def logger_messages
      @messages_thread_key ||= :"fluentd_logger_messages:#{object_id}"
      Thread.current[@messages_thread_key] ||= []
    end

    def map
      @map_thread_key ||= :"fluentd_logger_map:#{object_id}"
      Thread.current[@map_thread_key] ||= {}
    end

    def close
      @fluent_logger.close
    end

    def format_severity(severity)
      ActFluentLoggerRails::Logger::SEV_LABEL[severity] || 'ANY'
    end
  end
end
