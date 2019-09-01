module EMExt
  def self.spread(total_time, iterations)
    count = 1
    raise "No block given to spread." unless block_given?
    raise "Iterations must be at least one." unless iterations > 0

    timer = EventMachine::PeriodicTimer.new(total_time.to_f / iterations) do
      yield timer
      timer.cancel if (count += 1) > iterations
    end

    # Kick off the first iteration immediately
    yield timer
  end
end
