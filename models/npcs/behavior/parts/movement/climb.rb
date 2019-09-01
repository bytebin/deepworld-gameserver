module Behavior
  class Climb < Rubyhave::Behavior

    def behave
      direction = entity.direction

      [entity.last_climb_side, entity.last_climb_side * -1].each do |side|
        y = side * direction * -1

        if entity.in_bounds?(side, 0) && (entity.blocked?(side, 0) || entity.blocked?(side, y)) && !entity.blocked?(0, y)
          #puts "y, side, direction: y:#{y} side:#{side} direction:#{direction}"

          entity.move.y = y
          entity.last_climb_side = side
          entity.direction = direction

          entity.speed = entity.base_speed * 0.75
          entity.animate side == -1 ? 'climb-left' : 'climb-right'

          return Rubyhave::SUCCESS
        end
      end

      return Rubyhave::FAILURE
    end

    def can_behave?
      true
    end

    private
  end
end
