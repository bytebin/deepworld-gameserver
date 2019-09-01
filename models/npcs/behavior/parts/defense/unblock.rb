module Behavior
  class Unblock < Rubyhave::Behavior

    def on_initialize
      @toughness = @options['toughness'] || 1
      @rate = @options['rate'] || 1
      @dig_code = Game.item_code('ground/earth-dug')
    end

    def behave
      @rate.times do
        block = entity.position + Vector2[rand(entity.size.x), -rand(entity.size.y)]
        if zone.in_bounds?(block.x, block.y)
          front = zone.peek(block.x, block.y, FRONT)
          if front[0] > 0
            front_item = Game.item(front[0])
            if front_item.shape && front_item.category == 'ground'
              zone.update_block nil, block.x, block.y, FRONT, @dig_code
              zone.dig_block block, front[0], front[1]
            end
          end
        end
      end
    end
  end
end
