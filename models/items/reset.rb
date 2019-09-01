module Items
  class Reset < Base

    def use(params = {})
      # If no metadata yet, it's a placement, so stash state of all mechanicals in range
      if @meta['info'].blank?
        stash!
        alert "Reset switch configured."

      # Metadata is set, so activate reset
      else
        # Only allow if interval has elapsed
        time_left = (@meta['last'] || 0) + @meta['t'].to_i - Time.now.to_i
        if time_left <= 0
          reset!
          message! @meta['m']
          @zone.update_block nil, @position.x, @position.y, FRONT, nil, 1, nil, :skip
          @zone.add_block_timer @position, 1, ['front mod', 0]
        else
          alert "Reset locked for another #{time_left} second#{time_left != 1 ? 's' : ''}"
        end
      end
    end

    def range
      @meta['r'].to_i
    end

    def resettable_items
      Game.config.items_by_use['resettable']
    end

    def blocks_in_range
      chunks = @zone.chunks_in_rect(Rect.new(@position.x - range, @position.y - range, range * 2, range * 2))
      blocks = resettable_items.inject({}) do |hash, item|
        all_blocks = chunks.map{ |ch| ch.query(nil, nil, item.code) }.flatten(1)
        hash[item.code] = all_blocks.select{ |b| Math.within_range?(Vector2[b[0], b[1]], @position, range) }
        hash
      end
      blocks
    end

    def stash!
      blocks = blocks_in_range
      meta_keys = ['t1', 't2', 't3', 't4']
      info = {}

      blocks.each_pair do |item_code, blocks|
        next if blocks.blank?

        info[item_code] = []
        item = Game.item(item_code)
        blocks.each do |block|
          block_info = [block, @zone.peek(block[0], block[1], FRONT)[1]]

          if item.use.switched == 'MessageSign'
            meta = @zone.get_meta_block(block[0], block[1])
            block_info << meta.data.except('p')
          end

          info[item_code] << block_info
        end
      end

      @meta['info'] = info
    end

    def reset!
      return unless @meta['info']
      @meta['last'] = Time.now.to_i

      Player.find_by_id(BSON::ObjectId(@meta.player_id), { callbacks: false }) do |owner|
        if owner
          @meta['info'].each_pair do |item_code, blocks|
            begin
              blocks.each do |block|
                pos = Vector2[block[0][0], block[0][1]]
                unless @zone.block_protected?(pos, owner)
                  # If block is same item, reset
                  peek = @zone.peek(pos.x, pos.y, FRONT)
                  if peek[0] == item_code
                    # If mod is different, update
                    @zone.update_block nil, pos.x, pos.y, FRONT, nil, block[1], nil, :skip

                    # Update metadata if necessary
                    if block[2]
                      meta = @zone.get_meta_block(pos.x, pos.y)
                      meta.data.merge! block[2]
                      @zone.send_meta_block_message meta
                    end
                  end
                end
              end
            rescue
              p "Exception: #{$!} #{$!.backtrace.first(3)}"
            end
          end
        end
      end
    end


    private

    def meta_blocks_within_range
      @zone.meta_blocks_within_range(@position, (@meta['r'] || 1).to_i)
    end

  end
end
