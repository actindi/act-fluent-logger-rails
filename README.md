# Act::Fluent::Logger::Rails

Fluent logger.

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
    config.logger = ActFluentLoggerRails::Logger.new

create config/fluent-logger.yml

    development:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
    
    test:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
    
    production:
      fluent_host:   '127.0.0.1'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'

 * fluent_host: The host name of Fluentd.
 * fluent_port: The port number of Fluentd.
 * tag: The tag of the Fluentd event.
 * messages_type: The type of log messags. 'string' or 'array'.
   If it is 'string', the log messages is a String.
```
2013-01-18T15:04:50+09:00 foo {"messages":"Started GET \"/\" for 127.0.0.1 at 2013-01-18 15:04:49 +0900\nProcessing by TopController#index as HTML\nCompleted 200 OK in 635ms (Views: 479.3ms | ActiveRecord: 39.6ms)"],"level":"INFO"}
```
   If it is 'array', the log messages is an Array.
```
2013-01-18T15:04:50+09:00 foo {"messages":["Started GET \"/\" for 127.0.0.1 at 2013-01-18 15:04:49 +0900","Processing by TopController#index as HTML","Completed 200 OK in 635ms (Views: 479.3ms | ActiveRecord: 39.6ms)"],"level":"INFO"}
```

If your Rails version is older than v3.2.9, You must set a dummy value to config.log_tags.

    config.log_tags = ['nothing']


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
