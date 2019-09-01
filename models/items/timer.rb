module Items
  class Timer < Base

    def use(params = {})
      timer = @params[:timer]

      case timer.first
      when 'front mod'
        front = @zone.peek(@position.x, @position.y, FRONT)[0]
        @zone.update_block nil, @position.x, @position.y, FRONT, front, timer.last, nil, :skip

      when 'front item'
        @zone.update_block nil, @position.x, @position.y, FRONT, timer.last

      when 'bomb'
        @zone.explode @position, timer.last, @player, true, timer.last

      when 'bomb-fire'
        @zone.explode @position, timer.last, @player, false, timer.last, ['fire'], 'bomb-fire'

      when 'bomb-electric'
        @zone.explode @position, timer.last, @player, false, timer.last, ['energy'], 'bomb-electric'

      when 'bomb-frost'
        @zone.explode @position, timer.last, @player, false, timer.last, ['cold'], 'bomb-frost'

      # Liquids

      when 'bomb-water'
        @zone.explode @position, 4, @player, false, timer.last, ['cold'], 'bomb-frost'
        @zone.explode_liquid @position, 'liquid/water'

      when 'bomb-acid'
        @zone.explode @position, 4, @player, false, timer.last, ['acid'], 'bomb-acid'
        @zone.explode_liquid @position, 'liquid/acid'

      when 'bomb-lava'
        @zone.explode @position, 4, @player, false, timer.last, ['fire'], 'bomb-fire'
        @zone.explode_liquid @position, 'liquid/magma'

      when /^bomb-spawner/
        @zone.explode @position, timer.last, @player, false, timer.last, ['fire'], 'bomb-fire'
        if ents = Deepworld::Settings.items[timer.first]
          ents = ents.random
          timer.last.times do
            @zone.spawn_entity ents.random, @position.x, @position.y
          end
        end

      when 'bomb-dig'
        @zone.explode @position, timer.last, @player, false, timer.last
        distance = timer.last * 10
        (1..distance).each do |y|
          dig_position = @position + Vector2[0, y]
          dug = @zone.dig_block_if_possible(dig_position)
          return if dug == -1
        end

      when 'switch'
        # Change switch
        switch_front = @zone.peek(@position.x, @position.y, FRONT)
        switch_mod = switch_front[1]
        new_switch_mod = switch_mod % 2 == 0 ? switch_mod + 1 : switch_mod - 1 # Alternate odd and even mod
        @zone.update_block nil, @position.x, @position.y, FRONT, nil, new_switch_mod, nil, :skip

        # Change switched item(s)
        timer.last.each do |switched_block|
          switched_front = @zone.peek(switched_block.x, switched_block.y, FRONT)
          if Game.item(switched_front[0]).use.try(:switched)
            @zone.update_block nil, switched_block.x, switched_block.y, FRONT, switched_front[0], new_switch_mod, nil, :skip
          end
        end
      end
    end
  end
end