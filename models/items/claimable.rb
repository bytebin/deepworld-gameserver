module Items
  class Claimable < Base

    def use(params = {})
      if @item.use.claimable
        title = @item.title.downcase

        @meta ||= @zone.get_meta_block(@position.x, @position.y)

        # Only let one player claim an item
        if @meta.try(:player?)
          if @meta.player?(@player)
            alert "You have already claimed this #{title}."
          else
            if @meta['entry']
              alert Competition.entry_title(@meta)
            else
              Items::Owner.new(@player, { item: @item, meta: @meta }).use!
            end
          end
        else
          # If there's a per-zone limit, check if it has been reached
          player_id = @player.id.to_s
          if zone_limit = @item.use.claimable_zone_limit
            if zone.meta_blocks_with_item(@item.code).count{ |mb| mb.player_id == player_id } >= zone_limit
              alert "Sorry, you can only claim #{zone_limit} of these per world."
              return
            end
          end

          # If a competition, check competition entries limit
          if @item.use.competition && @zone.competition
            # Check cached participants first, otherwise reload competition participants field
            if claim_if_participation_allowed!(false)
              @zone.competition.reload(:participants) do |competition|
                claim_if_participation_allowed!
              end
            end

          # Otherwise, skip directly to claiming
          else
            claim!
          end
        end
      end
    end

    def claim!
      # Set meta if not yet set
      @meta ||= @zone.set_meta_block(@position.x, @position.y, @item)

      @meta.player_id = @player.id.to_s
      @meta['pn'] = @player.name
      alert "You claimed a #{@item.title.downcase}."
      @zone.send_meta_block_message @meta
      @player.queue_message EffectMessage.new(@position.x * Entity::POS_MULTIPLIER, @position.y * Entity::POS_MULTIPLIER, 'chime', 1)

      # Update competition if necessary
      if @item.use.competition && @zone.competition
        @zone.competition.increment_participation @player.id.to_s
      end
    end

    def claim_if_participation_allowed!(allow_claim = true)
      if (@zone.competition.participants[@player.id.to_s] || 0) >= @zone.competition.max_entries
        alert "Sorry, you can only claim #{@zone.competition.max_entries} of these in this competition."
        false
      else
        claim! if allow_claim
        true
      end
    end

  end
end