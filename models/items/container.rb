module Items
  class Container < Base

    def use(params = {})
      # Unlock if player has key
      if @meta.locked? && @player.has_key?(@meta.key)
        @meta.unlock!
      end

      # Prohibit use if locked by protectors
      if protectors = @meta['prot']
        if protectors.any?{ |prot| @zone.peek(prot[0], prot[1], FRONT)[0] == prot[2] }
          alert "This container is secured by protectors in the area."
          return
        end
      end

      # Prohibit use if locked by dungeon and player hasn't raided (but allow after enough time)
      if (@meta['dp'] && @meta['dp'][@player.id.to_s].nil?) && (@meta['dt'] && Time.now.to_i - @meta['dt'] < 60.minutes)
        alert "This container can only be looted by a raider or after 60 minutes."
        return
      end

      # Containers of plenty give loot once to each player
      if @item.use.plenty
        if loot_code = @meta['y']
          # Prevent multiple lootages
          if @player.loot?(loot_code)
            if @player.admin?
              alert "Loot code: #{loot_code}" and return
            else
              alert "You've already plundered this chest." and return
            end

          # Add loot code to player
          else
            @player.loots << loot_code
          end
        else
          alert "This chest cannot be plundered." and return
        end
      end

      # Transfer any special item
      transfer_special_item if @meta.special_item?

      # If container no longer has contents, change mod to zero
      if !@item.use.plenty
        new_mod = (@meta.special_item? or @meta.contents?) ? 1 : 0
        @zone.update_block nil, @position.x, @position.y, FRONT, @item.code, new_mod if new_mod != @params[:mod]
      end
    end

    def transfer_special_item
      static = @meta.data['l'].present? ? { @meta.data['l'] => (@meta.data['q'].present? ? @meta.data['q'].to_i : 1) } : nil
      plenty = @item.use.plenty

      # XP
      if @meta['xp'].present?
        @player.add_xp @meta['xp'].to_i
        @meta.data.delete 'xp' unless plenty
      end

      # Random goodies
      if @meta.special_item == '?'
        @meta.data.delete '$' unless plenty
        @meta.reindex
        Rewards::Loot.new(@player, types: @meta.item.loot, static: static).reward!
        Achievements::LooterAchievement.new.check(@player)
        @player.add_xp @meta.item.loot_xp

      # Machine part goodies
      elsif meta_item = Game.item(@meta.special_item)
        @meta.data.delete '$'

        # Machine part discovery
        if machine = %w{geck composter expiator recycler}.find{ |u| meta_item.use[u] }
          description = @zone.machine_description(machine)
          description_with_article = "a#{['a','e','i','o','u'].include?(description[0]) ? 'n' : ''} #{description}"
          @player.notify({ 't' => "You discovered #{description_with_article} component!", 'i' => meta_item.id }, 10)
          @player.notify_peers "#{player.name} discovered #{description_with_article} component.", 11
          @zone.discover_machine_part! machine.to_sym, meta_item.code, @player
          @zone.send_machines_status_message_to_all
        end

        # Discovery achievement
        Achievements::DiscoveryAchievement.new.check(@player, meta_item)
        @player.add_xp :machine_part
      end
    end

    def validate(params = {})
      @meta.present?
    end

  end
end