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
