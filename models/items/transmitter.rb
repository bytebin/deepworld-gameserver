module Items
  class Transmitter < Base

    def use(params = {})
      if meta = get_meta_block
        destination = meta.data['>']
        if destination
          destination_item = Game.item(@zone.peek(destination[0], destination[1], FRONT)[0])
          if destination_item.use.transmitted
            @player.teleport! Vector2[destination[0], destination[1]], false
          end
        end
      end
    end
  end
end
