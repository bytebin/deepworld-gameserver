module Behavior
  class Stuck < Rubyhave::Sequence
    def on_initialize
      @stuck_count = 0

      @stuck_position = entity.position
      @next_stuck_check = Time.now
    end

    def behave
      @stuck_count = 0
      entity.direction *= -1

      super
    end

    def can_behave?
      if Ecosystem.time > @next_stuck_check
        if (entity.position - @stuck_position).magnitude < 2
          @stuck_count += 1
        else
          @stuck_count = 0
        end

        @stuck_position = entity.position.dup
        @next_stuck_check = Ecosystem.time + 2.seconds
      end

      @stuck_count > 3
    end
  end
end
