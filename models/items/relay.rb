module Items
  class Relay < Base

    def use(params = {})
      # Begin by setting up normal switch
      @switch = Items::Switch.new(
        @player,
        zone: @zone,
        entity: @entity,
        position: @position,
        item: @item,
        mod: 0
      )
      @switch.use! activate: false
      @switchables = @switch.switchables

      return if @switchables.blank?

      activate_random = @meta['y'] == 'Random'
      activate_all = @meta['a'] == 'All'
      delay = @meta['d'].to_i
      reset = @meta['r'].to_i
      last_activated_at = @meta['laa'] || 0
      next_in_sequence = @meta['nis'] || 0

      # Random
      if activate_random
        # Activate all in random order with delay
        if activate_all

        # Single random use
        else
          switch! [@switchables.sample]
        end

      # Sequential
      else
        # Return to first switchable if reset is set and enough time has elapsed since last activation,
        # or if next opt is past sequence length
        should_reset = reset > 0 && Time.now.to_i - last_activated_at > reset
        if next_in_sequence >= @switchables.size || should_reset
          next_in_sequence = 0
        end

        # Activate next in sequence
        switch! [@switchables[next_in_sequence]]
        next_in_sequence += 1
        @meta['nis'] = next_in_sequence
      end

      # Update last activated at
      @meta['laa'] = Time.now.to_i
    end

    def switch!(switchables, delay = 0)
      total_delay = 0
      switchables.each do |switchable|
        # Delay - use zone timers
        if delay > 0
          total_delay += delay
          #@zone.add_block_timer @position, total_delay

        # No delay
        else
          switchable.use!
        end
      end
    end

  end
end