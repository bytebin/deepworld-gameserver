module Players
  class Placements
    attr_reader :player, :zone
    attr_accessor :transmittable_block

    def initialize(player)
      @player = player
      @latest = nil
    end

    def zone
      @player.zone
    end

    def latest_item
      @latest ? @latest.last : nil
    end

    def latest_position
      @latest ? @latest.first : nil
    end

    def place(position, item)
      return unless item.use
      linked = false

      if item.use.transmitted && @transmittable_block
        transmit_block position
        return
      end

      if @latest && item.use.present?
        linked ||= link_switched_items(item, position) if item.use.switched && !item.use.switch
        linked ||= link_transmit_items(item, position) if item.use.transmitted
      end

      @latest = [position, item] unless linked

      @transmittable_block = nil
    end

    def link_switched_items(item, position)
      linked = false

      if latest_item.use.switch || latest_item.use.trigger
        if meta = zone.get_meta_block(latest_position.x, latest_position.y)
          if meta.player?(player)
            # Link switch to switched item
            meta.data['>'] ||= []
            meta.data['>'] << [position.x, position.y]

            # Match mod between switch and switched items (allow colored doors, etc.) unless a custom switchable
            unless item.use.switched.is_a?(String)
              mod = zone.peek(latest_position.x, latest_position.y, FRONT)[1]
              zone.update_block nil, position.x, position.y, FRONT, item.code, mod, nil, :skip
            end
          end

          # Clear out the latest item if it's a single use
          linked = true
          @latest = nil unless latest_item.use.multi
        end
      end

      linked
    end

    def link_transmit_items(item, position)
      linked = false

      if latest_item.use.transmit
        # Only allow to place if within transmit distance range (admin can place any distance)
        if player.admin? || (latest_position - position).magnitude <= player.max_transmit_distance
          if meta = zone.get_meta_block(latest_position.x, latest_position.y)
            if meta.player?(player)
              # Update mod on transmitter
              zone.update_block nil, latest_position.x, latest_position.y, FRONT, latest_item.code, 1, nil, :skip

              # Link transmitter to location
              meta.data['>'] = [position.x, position.y]

              linked = true
              @latest = nil
            end
          end
        else
          player.alert "You can only transmit #{player.max_transmit_distance} blocks at your current engineering level."
        end
      end

      linked
    end

    def transmit_block(position)
      item = Game.item(@player.zone.peek(@transmittable_block.x, @transmittable_block.y, FRONT)[0])
      if item.transmittable
        @player.zone.update_block nil, @transmittable_block.x, @transmittable_block.y, FRONT, 0, 0
        @player.zone.update_block nil, position.x, position.y, FRONT, item.code, 0
      end

      @transmittable_block = nil
    end
  end
end
