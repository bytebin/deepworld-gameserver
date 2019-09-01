#!/usr/bin/env ruby
require 'syslog'
require 'bundler'

Bundler.require

load_paths = [
  '../../lib/ip.rb',
  'machine.rb'
  ]

class Monitor
  RUN_EVERY = 1 # 1 second

  def initialize
    Signal.trap("INT")  { shutdown! }
    Signal.trap("TERM") { shutdown! }

    # Open up the syslog
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS)

    @ip       = IP.get_ip(File.join(Deepworld::Loader.root, '../../tmp/ip.txt'))
    @machine  = Machine.register(@ip)
  end

  def log(l)
    msg = "[sm_#{Deepworld::Env.environment[0]}] " + l.to_s.gsub(/\%/, '(per)') # Replace percent sign to avoid syslog error

    Syslog.log Syslog::LOG_INFO, msg
    puts msg if Deepworld::Env.development?
  end

  def shutdown!
    log "Monitor shutdown"
    Kernel.exit 0
  end

  def run!
    log "Monitor startup"

    loop do
      sleep(RUN_EVERY)
      begin
        check_status
      rescue
        self.log message: "Monitor failure!", exception: $!.to_s, backtrace: $!.backtrace.first(5)
      end
    end
  end

  def check_status
    @machine.reload

    if @machine.upgrade
      self.log "Upgrade requested, touching upgrade.txt and shutting down."

      FileUtils.touch "#{Deepworld::Loader.root}/../../tmp/upgrade.txt"
      self.shutdown!

    elsif @machine.restart
      log "Restart requested, shutting down."

      self.shutdown!
    end
  end
end

# Load it
Deepworld::Loader.load!(load_paths)
Deepworld::Configuration.configure! Deepworld::Env.environment

# Run it
monitor = Monitor.new
monitor.run!

# Love it