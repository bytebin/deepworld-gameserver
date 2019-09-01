module Players
  module Appearance

    def randomize_appearance!
      self.appearance = Players::Appearance.random_appearance(self)
    end

    def self.random_appearance(player = nil)
      if Game.config.entities
        appearances = Game.config.entities.avatar.options

        appearance = {
          'c*' => appearances['skin-color'].random,
          'h*' => appearances['hair-color'].random,

          'h' => base_appearance_codes(player, 'hair').random,
          'fh' => Game.item_code('facialhair/none'), #base_appearance_codes(player, 'facialhair').random,

          't' => base_appearance_codes(player, 'tops', /(coat\-gray|coat\-reeses|plaid|suspenders)$/).random,
          'b' => base_appearance_codes(player, 'bottoms', /pants/).random,
          'fw' => base_appearance_codes(player, 'footwear').random,
          'hg' => base_appearance_codes(player, 'headgear', /(none|bowler|newsie)/).random,
          'fg' => base_appearance_codes(player, 'facialgear', /(none|monocle|tattoo\-2|glasses)$/).random
        }
        appearance.each_pair { |k, v| appearance[k] ||= 0 }
        appearance
      else
        {}
      end
    end

    def fix_appearance
      self.appearance.each_pair do |k, v|
        self.appearance[k] ||= 0
      end
    end

    def self.base_appearance_codes(player, type, match = nil)
      Game.items_by_category(type).map do |name, details|
        (details.base == true || player.nil? || player.admin) && (!match || name.match(match)) ? details.code : nil
      end.compact
    end

    def appearance_uniform
      if zone.biome == "space"
        return { 'hg' => 1377 }
      end

      case zone.scenario
        when 'Guild PvP'
          { 't' => 1301, 't*' => guild ? guild.color1 : 'ffffff', 'b' => 1380, 'b*' => guild ? guild.sign_color : '333333', 'fw' => 1360 }
        when 'Team PvP'
          color = { 'Red' => ['ff5544', '552211'], 'Blue' => ['4455ff', '112255'] }[pvp_team]
          { 't' => 1301, 't*' => color.first, 'b' => 1380, 'b*' => color.last, 'fw' => 1360, 'h*' => color.last }
        else nil
      end
    end

    def change_appearance_options(options)
      update_setting 'appearance', options
      zone.queue_message EntityStatusMessage.new([status])
    end

    def has_bonus_appearance_colors?
      inv.contains?(Game.item('accessories/makeup').code) || admin?
    end

  end
end
