RUN_TIME    = 300
SLEEP_TIME  = 30
CYCLES      = 1000000
SIMS        = 200
MAX_ZONES   = 30

def cycle_sims
  puts "\nRunnin the sims for #{RUN_TIME} seconds..."
  sim_thread = Thread.new { `bundle exec ruby simulator.rb -n #{SIMS} -m #{MAX_ZONES} -t #{RUN_TIME}` }
  sleepy RUN_TIME

  puts "\nSims dead, waiting #{SLEEP_TIME} seconds"
  sleepy SLEEP_TIME
end

def sleepy(secs)
  secs.times do
    sleep 1
    print '.'
  end
end

# ENV=staging ruby sim_cycle.rb
CYCLES.times.each { cycle_sims }
