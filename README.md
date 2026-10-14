# Act::Fluent::Logger::Rails

Fluent logger.

## Supported versions

 * Rails 7.0, 7.1, 7.2, 8.0, 8.1
 * Ruby 3.1+

## Installation

Add this line to your application's Gemfile:

    gem 'act-fluent-logger-rails'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install act-fluent-logger-rails

## Usage

in config/environments/production.rb

    config.log_level = :info
    config.logger = ActFluentLoggerRails::Logger.
      new(log_tags: {
            ip: :ip,
            ua: :user_agent
          })

Don't use config.log_tags.

`log_tags` are evaluated by `Rails::Rack::Logger` at the start of each request,
before the session and cookie middleware run, so they cannot read the session
(see #41). To log session values such as a user id, set them at run time from
the controller instead (see below).

### To define where to send messages to, either:

#### create config/fluent-logger.yml

    development:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
      severity_key:  'level'     # default severity

    test:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
      severity_key:  'level'     # default severity

    production:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
      severity_key:  'level'     # default severity

#### set an environment variable FLUENTD_URL

    http://fluentd.example.com:42442/foo?messages_type=string&severity_key=level

#### pass a settings object to ActFluentLoggerRails::Logger.new

    config.logger = ActFluentLoggerRails::Logger.
      new(settings: {
            host: '127.0.0.1',
            port: 24224,
            tag: 'foo',
            messages_type: 'string',
            severity_key: 'level'
          })

### Setting

 * fluent_host: The host name of Fluentd.
 * fluent_port: The port number of Fluentd.
 * tag: The tag of the Fluentd event.
 * messages_type: The type of log messages. 'string' or 'array'.
   If it is 'string', the log messages is a String.
```
2013-01-18T15:04:50+09:00 foo {"messages":"Started GET \"/\" for 127.0.0.1 at 2013-01-18 15:04:49 +0900\nProcessing by TopController#index as HTML\nCompleted 200 OK in 635ms (Views: 479.3ms | ActiveRecord: 39.6ms)"],"severity":"INFO"}
```
   If it is 'array', the log messages is an Array.
```
2013-01-18T15:04:50+09:00 foo {"messages":["Started GET \"/\" for 127.0.0.1 at 2013-01-18 15:04:49 +0900","Processing by TopController#index as HTML","Completed 200 OK in 635ms (Views: 479.3ms | ActiveRecord: 39.6ms)"],"severity":"INFO"}
```
 * severity_key: The key of severity(DEBUG, INFO, WARN, ERROR).
 * tls_options: A hash of tls options compatible with [fluent-logger-ruby](https://github.com/fluent/fluent-logger-ruby#tls-setting). The simplest being: 
	 <pre>tls_options:
	  use_default_ca: true</pre>

You can add any tags at run time. They are sent with the rest of the request's
messages and cleared when the messages are flushed.

   logger[:foo] = "foo value"

For example, to log a user id stored in the session:

```ruby
class ApplicationController < ActionController::Base
  before_action { logger[:uid] = session[:uid] }
end
```

With `flush_immediately: true` the tags are cleared after each message, so only
the next message carries them.

### Usage as a standalone logger

Typical usage is as a replacement for the default Rails logger, in which case
messages are collected and flushed automatically as part of the request
lifecycle. If you wish to use it instead as a separate logger and log to it
manually then it is necessary to initialize with the `flush_immediately` flag.

```ruby
ActFluentLoggerRails::Logger.new(flush_immediately: true)
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## How to run test with appraisal
```
gem install appraisal
bundle exec appraisal bundle
bundle exec appraisal rake
```

`rake spec` runs the unit specs and then the integration specs in `spec/integration`.
Those boot a small Rails app that logs to a fake fluentd over TCP. Each file runs in
its own process, since a Rails app boots only once per process. To run one:

```
bundle exec rspec spec/integration/logging_spec.rb
```
