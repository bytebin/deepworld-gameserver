module Rewards
  class Loot

    attr_accessor :options

    def self.live_only?
      Deepworld::Env.production?
    end

    def initialize(player, options = {})
      srand
      @player = player
      @level = options[:level] || @player.adjusted_skill('luck')
      @timed_bonuses = (Game.schedule.event_by_type("loot_bonus") || {})["bonus"] || []
      @message = options[:message] || 'You found:'

      if @static = options[:static]
        # Static loot hash
      else
        @types = [*(options[:types] || 'resources')]

        # Use options directly or cull from master collection using types
        @options = (options[:items] || Game.loot).select do |opt|
          @types.include? opt['type']
        end

        # Clear out non-live loot unless outside of production
        if self.class.live_only?
          @options.reject! do |option|
            option['live'] == false
          end
        end

        # Clear out stuff not available in current biome
        @options.reject! do |option|
          option["biome"] && option["biome"] != player.zone.biome
        end

        # Clear out not-yet-available stuff
        @options.reject! do |option|
          #option['available_after'] &&
        end

        # Clear out bonus items when bonus is not active
        @options.reject! do |option|
          option['bonus'] && !@timed_bonuses.include?(option['bonus'])
        end

        # Clear out loot that isn't in the config
        @options.reject! do |option|
          items = [option['wardrobe'], option['items']].flatten.select{ |i| i.is_a?(String) }
          items.any? do |i|
            item = Game.item(i)
            item.blank? || item.code == 0
          end
        end

        # Remove low frequency items if in easy zone
        @options.reject! do |option|
          option['frequency'] < (4 - player.zone.difficulty)
        end

        # Remove options that are beyond level (too rare) - but occasionally don't (based on level)
        if rand > (@level || 1) * 0.015
          min_freq = [18, 15, 12, 9, 7, 5, 4, 3, 2][@level] || 1
          @options.reject! do |option|
            option['frequency'] < min_freq
          end
        end

        # Clear out wardrobe items player already has
        @options.reject! do |option|
          option['wardrobe'] and code = Game.item_code(option['wardrobe']) and @player.wardrobe.include?(code)
        end

        # Remove premium items for free players
        @options.reject! { |option| option['premium'] } if @player.free?
      end
    end

    def reward!
      added_wardrobe = []
      added_inventory = []
      notification = []

      if @static
        @static.each_pair do |item_name, quantity|
          item = Game.item(item_name)
          @player.inv.add item.code, quantity, false
          @player.track_inventory_change :loot, item.code, quantity
          @player.event! :loot, item
          added_inventory << item.code
          notification << { item: item.code, text: "#{item.title} x #{quantity}" }
        end

      elsif option = random_option
        # Wardrobe
        if wardrobe = option['wardrobe']
          [*wardrobe].each do |item|
            item = Game.item(item)
            @player.wardrobe << item.code
            added_wardrobe << item.code
            notification << { item: item.code, text: "#{item.title} x 1" }
          end
        end

        # Inventory
        if items = option['items']
          [*items].each do |item|
            quantity = item.is_a?(Array) ? item.last : 1
            item = Game.item(item.is_a?(Array) ? item.first : item)

            # Adjust quantity for level if not a single item
            if quantity > 1
              level_multiplier = (@level - 1) * 0.05
              quantity += (quantity * level_multiplier).to_i
            end

            @player.inv.add item.code, quantity, false
            @player.track_inventory_change :loot, item.code, quantity
            @player.event! :loot, item
            added_inventory << item.code
            notification << { item: item.code, text: "#{item.title} x #{quantity}" }
          end
        end

        if crowns = option['crowns']
          amount = @player.premium ? crowns * 2 : crowns
          Transaction.credit(@player, amount, 'loot')
          sections = [{ title: @message }, Dialog.colored_text("#{amount} shiny crowns!", "ffd95f", @player)]
          unless @player.premium
            sections << Dialog.colored_text("\nUpgrade to premium to double your crown loot.", "bbbbbb", @player)
          end
          @player.show_dialog({ sections: sections})
        end
      end

      # Send messages
      @player.inv.send_message added_inventory if added_inventory.present?
      @player.queue_message WardrobeMessage.new(added_wardrobe) if added_wardrobe.present?

      if notification.present?
        if @player.v3?
          @player.show_dialog({ title: @message, sections: [{ list: notification }], sound: 'loot' })
        else
          @player.notify({ sections: [{ title: @message, list: notification }] }, 12)
        end
      end
    end

    def random_option
      loots = self.attempts.times.map { @options.random_by_frequency }.compact
      loots.sort_by{ |a| a['frequency'] }.first || { 'items' => [['accessories/shillings', 10]] }
    end

    def attempts
      @level >= 15 ? 3 : @level >= 10 ? 2 : 1
    end

    def rarity
      total_freq = 0
      rarities = @options.inject({}) do |hash, opt|
        items = [*opt['items']].map{ |i| Game.item([*i][0]) }
        items.each do |item|
          hash[item.category] ||= 0
          hash[item.category] += opt['frequency']
        end

        total_freq += opt['frequency']

        hash
      end
      rarities.keys.each{ |k| rarities[k] = (rarities[k].to_f / total_freq).round(3) }
      rarities
    end

  end
end
