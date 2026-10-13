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

    def tagged(*tags)
      request_local_set(:tags, tags.flatten)
      # Create the buffers before yielding so fibers started during the request share them.
      logger_messages
      map
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
      request_local_set(:tags, nil)
      map.clear
    end

    def add_tags
      tags = request_local_get(:tags)
      return unless tags
      @log_tags.keys.zip(tags).each do |k, v|
        map[k] = v
      end
    end

    def logger_messages
      request_local_get(:messages) || request_local_set(:messages, [])
    end

    def map
      request_local_get(:map) || request_local_set(:map, {})
    end

    # Per-request state. On Ruby 3.2+ it is kept in fiber storage, which fibers started
    # during the request (e.g. Async tasks under Falcon) inherit, so their messages are
    # flushed with the request. New threads inherit fiber storage too, so each value
    # records the thread that created it and values inherited by another thread are ignored.
    if Fiber.respond_to?(:[])
      def request_local_storage_get(key)
        Fiber[key]
      end

      def request_local_storage_set(key, value)
        Fiber[key] = value
      end
    else
      def request_local_storage_get(key)
        Thread.current[key]
      end

      def request_local_storage_set(key, value)
        Thread.current[key] = value
      end
    end

    def request_local_get(name)
      owner, value = request_local_storage_get(request_local_key(name))
      value if owner.equal?(Thread.current)
    end

    def request_local_set(name, value)
      request_local_storage_set(request_local_key(name), value.nil? ? nil : [Thread.current, value])
      value
    end

    def request_local_key(name)
      @request_local_keys ||= {}
      @request_local_keys[name] ||= :"act_fluent_logger_rails_#{name}_#{object_id}"
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
