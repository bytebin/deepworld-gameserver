module Items
  class Burst < Base

    def use(params = {})
      # Only burst if item is natural or can burst when not natural
      unless @item.use.burst.natural && !@zone.block_natural?(@position.x, @position.y)
        # Random chance of non-burst based on player's agility
        return if rand < @player.adjusted_skill_normalized('agility') * 0.5

        # Damage
        @zone.explode @position, @item.use.burst.range, nil, false, @item.use.burst.damage[1], [@item.use.burst.damage[0]], @item.use.burst.effect, nil, skill: ['survival', -0.5]

        # Kill block
        @zone.update_block nil, @position.x, @position.y, FRONT, 0
      end
    end

  end
end