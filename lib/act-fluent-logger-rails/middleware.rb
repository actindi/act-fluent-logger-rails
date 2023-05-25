# frozen_string_literal: true

module ActFluentLoggerRails
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      Rails.logger.request = request
      @app.call(env)
    end
  end
end
