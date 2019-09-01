module Players
  module Achievements

    def add_achievement(title)
      unless has_achieved?(title)
        @achievements[title] = { date: Time.now, play_time: play_time }

        update achievements: @achievements do
          achievement_cfg = Game.config.achievements[title]
          xp_bonus = achievement_cfg ? Game.config.achievements[title].xp || 2000 : 2000
          add_xp xp_bonus

          queue_message AchievementMessage.new(title, xp_bonus)
          notify title, 15 if v3?
          notify_peers "#{@name} earned the #{title.downcase} achievement.", 11
        end
      end
    end

    def has_achieved?(achievement_title)
      @achievements[achievement_title].is_a?(Hash)
    end

    def completed_achievements
      @achievements.select{ |k,v| v.is_a?(Hash) }
    end

    # Update deprecated achievements
    def clean_achievements
      # @achievements.keys.each do |k|
      #   m = /Legendary|Eminent/
      #   if k.match(m)
      #     @achievements[k.sub(m, 'Master')] = @achievements[k]
      #     @achievements.delete k
      #   end
      # end
    end

    def check_startup_achievements
      ::Achievements::AgeAchievement.new.check(self)
      ::Achievements::ArchitectAchievement.new.check(self)
    end

  end
end
