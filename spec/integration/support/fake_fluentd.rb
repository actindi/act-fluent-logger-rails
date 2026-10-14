require 'socket'
require 'msgpack'

# Accepts fluent-logger's forward protocol on a random local port and keeps the records,
# so the specs see what fluentd would receive.
class FakeFluentd
  attr_reader :port

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @records = []
    @mutex = Mutex.new
    @received = ConditionVariable.new
    Thread.new { loop { serve(@server.accept) } }
  end

  # Returns the records received before the first one the block matches, and drops them.
  def take_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    @mutex.synchronize do
      loop do
        if (index = @records.index { |record| yield record })
          taken = @records.shift(index)
          @records.shift
          return taken
        end
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise "fluentd didn't receive the expected record in #{timeout}s, got: #{@records.inspect}" if remaining <= 0
        @received.wait(@mutex, remaining)
      end
    end
  end

  private

  def serve(socket)
    Thread.new do
      # Feed chunks instead of Unpacker.new(socket).each, which doesn't stream on JRuby.
      unpacker = MessagePack::Unpacker.new
      loop do
        unpacker.feed_each(socket.readpartial(64 * 1024)) do |_tag, _time, record|
          @mutex.synchronize do
            @records << record
            @received.broadcast
          end
        end
      end
    rescue IOError, SystemCallError
      # fluent-logger closed or reset the connection
    end
  end
end
