# Times only this gem's part of a request (push_tags, 8 info lines, pop_tags and flush),
# directly on the logger and through the BroadcastLogger Rails 7.1+ wraps it in.
# fluent-logger's post is stubbed out, so the numbers don't include sending.
#
#   bundle exec ruby bench/logger.rb
require_relative '../spec/integration/support/rails_app'
require 'benchmark/ips'

boot_rails_app(fluentd: FakeFluentd.new(keep_records: false))
broadcast = Rails.logger
logger = broadcast.respond_to?(:broadcasts) ? broadcast.broadcasts.first : broadcast
logger.instance_variable_get(:@fluent_logger).define_singleton_method(:post) { |*| true }

tags = ['request-id', '192.0.2.1', 'bench', ['admin', 'staff']]
message = 'Processing by WelcomeController#index as HTML'

puts "#{RUBY_DESCRIPTION}, Rails #{Rails.version}"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  [['logger', logger], ['BroadcastLogger', broadcast]].uniq { |_, l| l }.each do |name, l|
    x.report(name) do
      l.push_tags(*tags)
      8.times { l.info(message) }
      l.pop_tags(tags.size)
      l.flush
    end
  end
end
