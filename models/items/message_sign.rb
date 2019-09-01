module Items
  class MessageSign < Base

    def use(params = {})
      if switch = params[:switch]
        msg = (switch.meta['m'] || '').dup
        can_lock = @meta['lock'] == 'Yes'
        is_locked = can_lock && @meta['locked'] == true
        unlock = msg.blank?

        # If locked, only an empty message will unlock
        if is_locked
          if unlock
            @meta.data.delete 'locked'
            msg = ''
          else
            return
          end
        end

        # Replace interpolations
        msg = Items::DynamicMessage.new(@meta).interpolate(msg, switch.entity)

        # Cut string into lines
        line_max_length = 20
        msg = msg.scan(/.{1,#{line_max_length}}\b|.{1,#{line_max_length}}/).map(&:strip)

        # Set meta text values
        %w{t1 t2 t3 t4}.each_with_index do |t, idx|
          @meta[t] = msg[idx] || ''
        end

        # Lock if necessary
        @meta['locked'] = true if can_lock && !unlock

        send_fx! 'area steam', 10

        @zone.send_meta_block_message @meta
      end
    end

    def send_fx!(type, data)
      fxx = (@position.x + (@item.block_size[0]*0.5)) * Entity::POS_MULTIPLIER
      fxy = (@position.y - (@item.block_size[1]*0.5) + 1) * Entity::POS_MULTIPLIER
      @zone.queue_message EffectMessage.new(fxx, fxy, type, data)
    end
  end
end