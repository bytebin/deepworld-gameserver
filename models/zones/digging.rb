module Zones
  module Digging

    def dig_block(position, item_code, mod)
      @dig_queue_lock.synchronize do
        @dig_queue.push [Time.now + 10.seconds, position, item_code, mod]
      end
    end

    def dig_block_if_possible(position)
      if in_bounds?(position.x, position.y)
        front = peek(position.x, position.y, FRONT)
        front_item = Game.item(front[0])
        if front_item.diggable
          dug_item_code = Game.item_code('ground/earth-dug')
          update_block nil, position.x, position.y, FRONT, dug_item_code
          dig_block position, front[0], front[1]
          1
        elsif !front_item.shape
          0
        else
          -1
        end
      else
        -1
      end
    end

    def process_dig_queue(time = Time.now)
      # Process dig changes
      @dig_queue_lock.synchronize do
        dug_code = Game.item_code('ground/earth-dug')
        dig_to_idx = nil
        @dig_queue.each_with_index do |dig, idx|
          break unless time > dig.first
          dig_pos = dig[1]
          dig_item = dig[2]
          dig_mod = dig[3]
          update_block nil, dig_pos.x, dig_pos.y, FRONT, dig_item, dig_mod if peek(dig_pos.x, dig_pos.y, FRONT)[0] == dug_code
          dig_to_idx = idx
        end

        @dig_queue.slice! 0..dig_to_idx if dig_to_idx
      end
    end

  end
end