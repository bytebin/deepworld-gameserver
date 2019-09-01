module Players
  module Guild

    def fetch_guild
      self.reload(:guild_id) do
        if self.guild_id
          ::Guild.find_by_id(self.guild_id) do |g|
            self.guild = g
            yield g if block_given?
          end
        else
          self.guild = nil
          yield nil if block_given?
        end
      end
    end

    def guild_name
      guild ? guild.name : nil
    end

    def guild_short_name
      if zone.scenario == 'Team PvP'
        pvp_team
      elsif guild
        guild.short_name
      else
        nil
      end
    end

  end
end