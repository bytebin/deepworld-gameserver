module Behavior
  class Walk < Rubyhave::Behavior
    def on_initialize
      @acrophobic = @options['acrophobic']
    end

    def behave
      @floor_peek = nil

      # Bring the y back in line
      entity.move.y = (entity.position.y - entity.position.y.floor).round(1)

      # Modify movement and speed if on a moving surface
      if floor_item.use['move']
        move_direction = floor_mod == 0 ? 1 : -1
        entity.move.x = move_direction
        entity.speed = floor_item.power
        entity.animate 'idle'

        # Flip direction to direction of movement more often (so they struggle less)
        entity.direction = move_direction if rand < 0.333

      # Otherwise use default direction and speed
      else
        entity.move.x = entity.direction
        entity.speed = entity.base_speed
        entity.animate @options['animation'] || 'walk'
      end

      return Rubyhave::SUCCESS
    end


    def can_behave?
      entity.grounded?(entity.direction) && !entity.blocked?(entity.direction, 0) && !entity.character.try(:stationary)
    end

    def floor_peek
      unless @floor_peek
        (0..2).each do |x|
          xx = entity.position.x - x
          break if xx < 0
          @floor_peek = zone.peek(xx, entity.position.y + 1, FRONT)
          break if @floor_peek[0] > 0
        end
      end
      @floor_peek
    end

    def floor_item
      Game.item(floor_peek[0])
    end

    def floor_mod
      floor_peek[1]
    end

  end
end
