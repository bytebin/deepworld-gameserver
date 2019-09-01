module Achievements
  class AgeAchievement < BaseAchievement

    def check(player)
      self.remaining_achievements(player).each_pair do |title, config|
        created_before = config.created_before ? Time.parse(config.created_before.to_s) : Time.now
        created_after = config.created_after ? Time.parse(config.created_after.to_s) : Time.utc(2012, 1, 1)
        play_time = config.play_time || 0

        if (player.created_at >= created_after and player.created_at <= created_before and player.play_time > play_time)
          player.add_achievement title
        end
      end
    end

  end
end