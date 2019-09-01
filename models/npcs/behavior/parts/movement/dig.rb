module Behavior
  class Dig < Rubyhave::Behavior

    def behave
      dig_position = Vector2[entity.position.x + entity.direction, entity.position.y].fixed
      dug = entity.zone.dig_block_if_possible(dig_position)
      return Rubyhave::FAILURE
    end

  end
end
