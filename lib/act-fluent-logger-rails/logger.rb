# -*- coding: utf-8 -*-
require 'fluent-logger'
require 'active_support/core_ext'
require 'uri'
require 'cgi'

module ActFluentLoggerRails

  module Logger

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

    def self.new(config_file: Rails.root.join("config", "fluent-logger.yml"), log_tags: {})
      Rails.application.config.log_tags = [ ->(request) { request } ] unless log_tags.empty?
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
      }
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
        messages_type: params["messages_type"].try(:first)
      }.stringify_keys
    end

    def tagged(*tags)
      @request = tags[0][0]
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
      @messages_type = (options[:messages_type] || :array).to_sym
      @tag = options[:tag]
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(nil, host: host, port: port)
      @severity = 0
      @messages = []
      @log_tags = log_tags
      @map = {}
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

      if message.is_a? Exception
        error_message = message.message + "\n" + message.backtrace.join("\n") + "\n"
        message = error_message
      end

      if message.encoding == Encoding::UTF_8
        @messages << message
      else
        @messages << message.dup.force_encoding(Encoding::UTF_8)
      end
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
      @map[:level] = format_severity(@severity)
      @map[:severity] = format_severity(@severity)
      @log_tags.each do |k, v|
        @map[k] = case v
                  when Proc
                    v.call(@request)
                  when Symbol
                    @request.send(v)
                  else
                    v
                  end rescue :error
      end
      @fluent_logger.post(@tag, @map)
      @severity = 0
      @messages.clear
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
