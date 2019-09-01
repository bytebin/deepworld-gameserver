#!/usr/bin/env ruby
require 'syslog'

def log!(l)
  Syslog.log Syslog::LOG_INFO, "[sm_#{ENV['ENV'][0]}]" + l.to_s.gsub(/\%/, '(per)') # Replace percent sign to avoid syslog error
end

raise "Do not run this outside of staging/production!" unless ['production', 'staging'].include?(ENV['ENV'])

# Open the syslog
Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS)
upgrade_file = File.expand_path('../../tmp/upgrade.txt', __FILE__)

# We're finished if no file or modified_date is equal to contents
unless File.exists?(upgrade_file)
  log! "[Bootstrap]No upgrade.txt found"
  exit(0)
end

if File.mtime(upgrade_file).to_i == File.read(upgrade_file).to_i
  log! "[Bootstrap]upgrade.txt date matches modified, not upgraded"
  system 'restart deepworld-gameservers'
else
  log! "[Bootstrap]upgrade.txt has been modified, upgrading"

  system 'stop deepworld-gameservers'
  system 'git reset --hard HEAD'
  system 'git clean -f -d'
  system "git checkout #{ENV['BRANCH'] || ENV['ENV']}"
  system 'git pull'
  system 'bundle install --without development test --deployment'
  system 'cd script/deep_stats && bundle install --without development test --deployment && cd ..'
  system 'cd script/monitor && bundle install --without development test --deployment && cd ..'
  system 'rake build'
  system 'start deepworld-gameservers'
  system 'restart deepworld-stats'

  # Set the contents and modified at
  now = Time.now.to_i
  File.open(upgrade_file, 'w') {|f| f.write(now) }
  File.utime(now, now, upgrade_file)
end

exit(0)
