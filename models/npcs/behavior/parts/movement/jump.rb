module Behavior
  class Jump < Rubyhave::Behavior
    def on_initialize
      @to_jump = 0
    end

    def behave
      entity.speed = entity.base_speed * 1.75

      if @to_jump == 1
        entity.move.y = -2
        entity.move.x = entity.direction
      else
        entity.move.y = -1
      end

      entity.animation = 1
      @to_jump -= 1

      return Rubyhave::SUCCESS
    end

    def can_behave?
      @to_jump ||= 0
      (@to_jump > 0 || entity.grounded?) && (@to_jump > 0 || (@to_jump = blocked_height)) && !entity.character.try(:stationary)
    end

    def blocked_height
      (0..@options['jump']).each.detect do |block|
        !entity.blocked?(entity.direction, -block)
      end
    end

  end
end
