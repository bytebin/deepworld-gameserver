module Zones
  module Timers

    def add_block_timer(position, delay, timer, player = nil)
      idx = block_index(position.x, position.y)

      @block_timer_lock.synchronize do
        @block_timer_queue[idx] ||= [Time.now + delay, timer, player]
      end
    end

    def remove_block_timer(position)
      idx = block_index(position.x, position.y)
      @block_timer_lock.synchronize do
        @block_timer_queue.delete idx
      end
    end

    def process_block_timers(force = false)
      Game.add_benchmark :process_block_timers do
        time = Time.now
        ready_timers = []

        @block_timer_lock.synchronize do
          # Get timers that are ready
          ready_timers = @block_timer_queue.select{ |idx, timer| force || time > timer[0] }
          @block_timer_queue.reject!{ |idx, timer| ready_timers[idx].present? }
        end

        ready_timers.each do |idx, timer|
          process_block_timer block_position(idx), timer[1], timer[2]
        end
      end
    end

    def process_block_timer(position, timer, player = nil)
      Items::Timer.new(player, zone: self, position: position, timer: timer).use!
    end

    def get_block_timer(position)
      idx = block_index(position.x, position.y)
      @block_timer_queue[idx]
    end

    def block_timers_count
      @block_timer_lock.synchronize do
        @block_timer_queue.size
      end
    end

  end
end