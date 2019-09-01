module Items
  class Switch < Base

    attr_reader :switchables

    def use(params = {})
      if @meta = @zone.get_meta_block(@position.x, @position.y)
        timer = @meta.data['t'].to_i
        mod = @params[:mod]

        return if timer > 0 && mod % 2 == 1 # Don't allow deactivation of timed switch

        # Switch the switch itself
        new_switch_mod = mod % 2 == 0 ? mod + 1 : mod - 1 # Alternate odd and even mod
        @zone.update_block nil, @position.x, @position.y, FRONT, nil, new_switch_mod, @zone.block_owner(@position.x, @position.y, FRONT), :skip

        # Emote if message
        message! @meta['m']

        # Create switchable objects for all blocks affected by switch
        @switchables = []
        switched_blocks = @meta.data['>'] || [] # Get switched items from metadata
        switched_blocks.each_with_index do |switched_block|
          switched_peek = @zone.peek(switched_block.first, switched_block.last, FRONT)
          switched_item = Game.item(switched_peek[0])
          switched_mod = switched_peek[1]
          if switched_item.use.switched
            @switchables << Items::Switchable.new(
              @player,
              zone: @zone,
              entity: @entity,
              position: Vector2[switched_block.first, switched_block.last],
              item: switched_item,
              mod: switched_mod
            )
          end
        end

        if params[:activate] != false
          # If switch is configured as a string, use custom activator
          if @item.use.switch.is_a?(String)
            if clazz = "Items::#{@item.use.switch}".constantize
              clazz.new(@player, entity: @entity, item: @item, meta: @meta).use!(switchables: @switchables)
            end
          # Default activator
          else
            switch! @switchables
          end

          # Add zone timer if a timed switch
          if timer > 0
            block_positions = switched_blocks.map{ |b| Vector2[b.first, b.last] }
            @zone.add_block_timer @position, timer, ['switch', block_positions]
          end
        end
      end
    end

    def switch!(switchables)
      switchables.each do |switchable|
        switchable.use! switch: self
      end
    end

  end
end
