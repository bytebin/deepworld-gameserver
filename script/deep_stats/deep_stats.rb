#!/usr/bin/env ruby
require 'optparse'
require 'bundler'
Bundler.require

DEFAULTS = {
  interval: 15,
  sink: 'mongo',
  process_string: 'ruby deepworld.rb'
}

load_paths = [
  '../../lib/ip.rb',
  './sinks',
  './plugins',
  'os.rb',
  'stats_collector.rb']

class OptionParser
  def self.parse
    options = DEFAULTS

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: deepstats.rb [-i --interval for collection]"

      opts.on( '-i', '--i seconds', 'Interval between instrumentation runs') do |i|
        options[:interval] = i
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end

    optparse.parse!
    options
  end
end

class DeepStats
  def initialize(options)
    @sink = Kernel.const_get("#{options[:sink].capitalize}StatsSink").new
    @collector = StatsCollector.new(options[:process_string])
    @pids = []

    EM.epoll
    EM.run do
      Signal.trap("INT")  { shutdown }
      Signal.trap("TERM") { shutdown }

      EM.error_handler do |e|
        puts "Error raised during event loop:\n#{e.message}\n#{e.backtrace.join("\n")}"
      end

      EventMachine::add_periodic_timer(options[:interval]) { collect }
    end
  end

  def collect
    defer do
      data = @collector.collect
      @sink.store(data)
    end
  end

  def shutdown
    EM.stop_event_loop
  end

  private

  def defer &block
    begin
      yield
    rescue Exception => e
      puts e.to_s
      puts e.backtrace
      EM.stop_event_loop
    end
  end
end

Deepworld::Loader.load!(load_paths)
Deepworld::Configuration.configure! Deepworld::Env.environment

options = OptionParser.parse
DeepStats.new(options)