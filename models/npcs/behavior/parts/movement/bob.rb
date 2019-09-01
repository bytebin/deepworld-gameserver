module Behavior
  class Bob < Rubyhave::Behavior

    def on_initialize
      @direction = -1
      @bobble = 0.5
    end

    def behave
      # Flip the bobble direction
      @direction = @direction * -1
      entity.speed = entity.base_speed * 0.5

      entity.move.y = @bobble * @direction
      entity.move.x = entity.direction
      entity.animation = [0,1].random

      return Rubyhave::SUCCESS
    end

    def can_behave?
      entity.wet?(0,0) && entity.wet?(0,1) && !entity.blocked?(entity.direction, 0)
    end
  end
end
