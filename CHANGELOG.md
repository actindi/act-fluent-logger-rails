## Unreleased
* Don't raise `ArgumentError` when logging a String with an invalid byte sequence (#97). Messages are now skipped only when they're `nil` or an empty String, like `::Logger`, instead of `blank?`, so whitespace-only messages are sent. This makes the logger's part of a request 7–10% faster on CRuby and about 30% on JRuby
* Use Symbol keys for the per-thread buffers and look them up once per flush, which makes the logger's part of a request about 12% faster on CRuby and 27% on JRuby
* Add `bench/request.rb` to measure allocations and speed per request through a Rails app
* Add integration specs that log from a real Rails app to a fake fluentd
* Send `log_tags` with every line of a request when `flush_immediately` is true, not only the first (#89)
* Run CI on JRuby
* Don't allocate an Array per `log_tags` entry on each flush

## 0.7.0 / Oct 13 2026
* Package only `lib/`, README, CHANGELOG and LICENSE in the gem, not the specs and development files
* Require fluent-logger 0.9.1 or later (TLS support for `tls_options`, and a fix for invalid messages polluting the next one)
* Add `logger` as a runtime dependency, since it is a bundled gem from Ruby 4.0
* Make `silence`, `log_at` and symbol levels like `logger.level = :warn` work. `FluentLogger` overrode `level`, so it ignored the per-thread level these use (thanks @costa, from #66)
* Don't clear `config.log_tags` when another logger is created without `log_tags` (e.g. for Delayed::Job)
* Send `log_tags` on Rails 7.2+, where `Rails::Rack::Logger` sets them with `push_tags` instead of `tagged`
* Keep Array values of `log_tags` instead of flattening them into the following tags (based on #65)
* Drop support for Rails < 7.0 and Ruby < 3.1
* Parse `FLUENTD_URL` query parameters with `URI.decode_www_form`, since `CGI.parse` is not available in Ruby 4.0
* Require only the ActiveSupport core extensions the logger uses instead of all of `active_support/core_ext`, so Rails 7.0's `disable_to_s_conversion` is not preempted during `Bundler.require`
* Require `logger` before ActiveSupport so ActiveSupport < 7.1 loads with concurrent-ruby 1.3.5+

## 0.6.4 / Feb 19 2022
* Rails 7
* Fix the name of the gemfile used by Appraisal
* Replace Travis CI with GitHub Actions

## 0.6.3 / Mar 22 2020
* Support tls_options #63

## 0.6.2 / Jan 8 2020
* Rails 6.1

## 0.6.1 / Jan 8 2020
* Fix warning printed when use Rails 6

## 0.6.0 / Nov 23 2019

* Rails 6
* Make Thread Safe

## 0.5.0 / April 29 2017

* Rails 5.2
* support nanosecond_precision(Support nanosecond precision when sending logs to Fluentd #43)*

## 0.4.0 / April 29 2017

* Rails 5.1

## 0.3.1 / August 18 2016

* Replace dependency from rails to railties and activesupport.

## 0.3.0 / July 12 2016

* Rails 5

## 0.2.0 / Mar 20 2016

* Add severity_key parameter. It is The key of severity(DEBUG, INFO, WARN, ERROR).

## 0.1.10 / Dec 23 2015

* flush immediately.

## 0.1.9 / Dec 16 2015

 * Added settings: parameter to ActFluentLoggerRails::Logger.new.

## 0.1.8 / Nov 14 2015

 * Output Object#inspect if message is not String and not Exception.

## 0.1.7 / July 30 2015

 * Be able to log exceptions #15.

## 0.1.6 / March 20 2015

 * Fix incompatible character encodings #13.

## 0.1.5 / July 19 2014

 * Fix keynames of EVN['FLUENTD_URL']

## 0.1.4 / July 18 2014

 * Enable to use EVN['FLUENTD_URL']

## 0.1.3 / April 11 2014

 * Rails 4.1.0

## 0.1.2 / September 30 2013

 * Add 'gem.license = "MIT"' to gemspec.

## 0.1.1 / September 26 2013

 * Add log_tags feature.

## 0.1.0 / September 16 2013

 * Rails 4.0.0

## 0.0.4 / January 19 2013

 * Add messages_type parameter to fluent-logger.yml to specifying
   output messages type 'string' or 'array'.  Thanks to davidrenne.
