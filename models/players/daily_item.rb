module Players
  module DailyItem

    def increment_daily_item(xp)
      return if xp >= 2000 || level < 2

      # Start time is 4 PM CST
      key = Players::DailyItem.time_key
      no_daily_xp_yet = @xp_daily[key].nil?
      @got_daily_loot = false if no_daily_xp_yet
      @xp_daily[key] ||= 0
      @xp_daily[key] += xp
      todays_xp = @xp_daily[key]

      item = Players::DailyItem.item(self)
      requirement = Players::DailyItem.requirement

      if todays_xp >= requirement
        if !@got_daily_loot
          if !@loots.include?(key)
            @loots << key
            update loots: @loots
            @got_daily_loot = true

            # No item, so random loot
            if !item
              Rewards::Loot.new(self, types: ['treasure+', 'armaments+']).reward!

            # Wardrobe
            elsif item.wardrobe
              @wardrobe << item.code unless @wardrobe.include?(item.code)
              queue_message WardrobeMessage.new([item.code])

            # Named item
            else
              @inv.add item.code, Players::DailyItem.quantity, true
              track_inventory_change :daily_loot, item.code, Players::DailyItem.quantity
            end

            if item
              @items_looted_hash[item.code.to_s] ||= 0
              @items_looted_hash[item.code.to_s] += (Players::DailyItem.quantity || 1)
            end

            alert_profile "You've earned today's daily loot!",
              Players::DailyItem.description(self)

          # Cache that we got daily loot for this session
          else
            @got_daily_loot = true
          end
        end

      elsif todays_xp >= requirement * 0.5
        unless key == @last_daily_item_hint_at
          halfway = xp == requirement * 0.5 ? 'halfway' : 'more than halfway'
          alert_profile "You're #{halfway} to earning today's daily loot!",
            "Only #{requirement - todays_xp}xp to go!"
          update last_daily_item_hint_at: key
        end

      # First XP sends message describing loot
      elsif no_daily_xp_yet
        show_addendum = loots.size < 10
        addendum = show_addendum ? "\n\nNote: Achievement XP does not count towards daily loot progress" : ""

        alert_profile "Score #{requirement}xp to earn today's loot!",
          Players::DailyItem.description(self) + addendum
      end
    end

    def self.time_key
      (Time.now.utc - 22*3600).strftime('%Y-%m-%d')
    end

    def self.info
      Game.config.daily_bonuses[Players::DailyItem.time_key]
    end

    def self.item(player)
      if i = Players::DailyItem.info
        if i['item_female'] && player.settings['lootPreference'] == 1
          Game.item(i['item_female'])
        else
          Game.item(i['item'])
        end
      end
    end

    def self.quantity
      if i = Players::DailyItem.info
        i['quantity'] || 1
      else
        1
      end
    end

    def self.description(player)
      item = Players::DailyItem.item(player)
      if item
        item.wardrobe ? item.title : "#{Players::DailyItem.quantity} x #{item.title}"
      else
        "#{Players::DailyItem.quantity} x Random Loot"
      end
    end

    def self.requirement
      if i = Players::DailyItem.info
        i['xp'] || 1000
      else
        2000
      end
    end

  end
end
