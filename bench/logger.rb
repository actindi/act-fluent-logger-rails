# Times only this gem's part of a request (push_tags, 8 info lines, pop_tags and flush),
# directly on the logger and through the BroadcastLogger Rails 7.1+ wraps it in.
# fluent-logger's post is stubbed out, so the numbers don't include sending.
#
#   bundle exec ruby [--yjit] bench/logger.rb
#
# Rails turns YJIT on outside development and test from 7.2, so measure with and without it.
require_relative '../spec/integration/support/rails_app'
require 'benchmark/ips'

boot_rails_app(fluentd: FakeFluentd.new(keep_records: false))
broadcast = Rails.logger
logger = broadcast.respond_to?(:broadcasts) ? broadcast.broadcasts.first : broadcast
logger.instance_variable_get(:@fluent_logger).define_singleton_method(:post) { |*| true }

tags = ['request-id', '192.0.2.1', 'bench', ['admin', 'staff']]
# The lines Rails logs for a request to the integration app
messages = [
  'Started GET "/" for 192.0.2.1 at 2026-10-14 12:22:29 +0900',
  'Processing by WelcomeController#index as HTML',
  '  Parameters: {"uid" => "u1"}',
  'in the controller',
  '  Rendering text template',
  '  Rendered text template (Duration: 0.0ms | GC: 0.0ms)',
  'Completed 200 OK in 2ms (Views: 1.3ms | GC: 0.0ms)',
  'Redirected to http://example.org/',
]

puts "#{RUBY_DESCRIPTION}, YJIT #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'on' : 'off'}, Rails #{Rails.version}"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  [['logger', logger], ['BroadcastLogger', broadcast]].uniq { |_, l| l }.each do |name, l|
    x.report(name) do
      l.push_tags(*tags)
      messages.each { |message| l.info(message) }
      l.pop_tags(tags.size)
      l.flush
    end
  end
end
