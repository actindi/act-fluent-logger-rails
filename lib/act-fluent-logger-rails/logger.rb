# -*- coding: utf-8 -*-
require 'fluent-logger'

module ActFluentLoggerRails

  class Logger < ::ActiveSupport::TaggedLogging
    def initialize
      config_file   = Rails.root.join("config", "fluent-logger.yml")
      fluent_config = YAML.load(ERB.new(config_file.read).result)[Rails.env]
      settings = {
        tag:  fluent_config['tag'],
        host: fluent_config['fluent_host'],
        port: fluent_config['fluent_port']
      }
      @level = SEV_LABEL.index(Rails.application.config.log_level.to_s.upcase)
      super(::ActFluentLoggerRails::FluentLogger.new(settings, @level))
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < @level
      message = (block_given? ? block.call : progname) if message.blank?
      return true if message.blank?
      @logger.add_message(severity, message)
      true
    end

    def tagged(*tags)
      super(*tags)
    ensure
      @logger.flush
    end

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)
  end

  class FluentLogger < ActiveSupport::BufferedLogger
    def initialize(options, level=DEBUG)
      self.level = level
      port    = options[:port]
      host    = options[:host]
      @tag = options[:tag]
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(nil, host: host, port: port)
      @severity = 0
      @messages = []
    end

    def add_message(severity, message)
      @severity = severity if @severity < severity
      @messages << message
    end

    def flush
      return if @messages.empty?
      @fluent_logger.post(@tag, messages: @messages, level: format_severity(@severity))
      @severity = 0
      @messages.clear
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
