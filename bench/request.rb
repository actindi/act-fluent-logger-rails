# Sends requests through the integration app in spec/integration and reports the
# allocations per request (all of them, this gem's and fluent-logger's) and requests/s.
#
#   bundle exec ruby [--yjit] bench/request.rb [--flush-immediately] [--string] [--unix-socket]
#
# Allocations need CRuby (memory_profiler). Run it before and after a change.
require 'tmpdir'
require_relative '../spec/integration/support/rails_app'
require 'benchmark/ips'

logger_options = { flush_immediately: ARGV.include?('--flush-immediately') }
ENV['FAKE_FLUENTD_MESSAGES_TYPE'] = 'string' if ARGV.include?('--string')
socket_path = File.join(Dir.mktmpdir, 'fluentd.sock') if ARGV.include?('--unix-socket')
boot_rails_app(fluentd: FakeFluentd.new(keep_records: false, socket_path: socket_path), **logger_options)

session = Rack::MockRequest.new(Rails.application)
headers = { 'REMOTE_ADDR' => '192.0.2.1', 'HTTP_USER_AGENT' => 'bench' }
request = proc { session.get('/', headers) }
100.times(&request)

puts "#{RUBY_DESCRIPTION}, YJIT #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'on' : 'off'}, Rails #{Rails.version}, #{logger_options}, messages_type: #{ENV.fetch('FAKE_FLUENTD_MESSAGES_TYPE', 'array')}, #{socket_path ? 'Unix socket' : 'TCP'}"

if RUBY_ENGINE == 'ruby'
  require 'memory_profiler'

  count = 500
  report = MemoryProfiler.report { count.times(&request) }
  lib = File.expand_path('../lib/', __dir__)
  per_request = ->(entries) { entries.sum { |entry| entry[:count] }.fdiv(count).round(1) }

  puts "Objects allocated per request:"
  puts "  total:                   #{report.total_allocated.fdiv(count).round(1)}"
  puts "  act-fluent-logger-rails: #{per_request.(report.allocated_objects_by_file.select { |e| e[:data].start_with?(lib) })}"
  puts "  fluent-logger + msgpack: #{per_request.(report.allocated_objects_by_gem.select { |e| e[:data].start_with?('fluent-logger', 'msgpack') })}"
  report.allocated_objects_by_location.select { |e| e[:data].start_with?(lib) }.each do |e|
    puts "    #{e[:data].delete_prefix(lib)}: #{e[:count].fdiv(count).round(1)}"
  end
end

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  x.report('GET /', &request)
end
