module Achievements
  class BaseAchievement
    def initialize
      @achievements = Game.config.achievements_by_type(self.class.name.split('::').last)
      @achievements.each_pair do |title, config|
        config.title = title
      end
    end

    # Increment achievement progress and add actual achievement if threshold is hit
    def progress(player, achievements, amount)
      progressed_keys = []

      [achievements].flatten.each do |achievement|
        progress_amount = 0

        # Progress method asks player object directly for progress (e.g., items crafted)
        if achievement.progress_method
          progress_amount = self.class.progress_by_method(player, achievement.progress_method)

        # Otherwise, we rely on a progress counter
        elsif progress_key = achievement.progress

          # Only progress each key a max of one time
          unless progressed_keys.include?(progress_key)
            player.progress[progress_key] ||= 0
            player.progress[progress_key] += amount
            progressed_keys << progress_key
          end

          progress_amount = player.progress[progress_key]
        end

        # Register achievement if progress is >= required amount (if already achieved, will be filtered out in add_achievement method)
        if achieved?(player, achievement, progress_amount)
          player.add_achievement achievement.title

        # Otherwise, send achievement update
        else
          if achievement.notify
            perc = achieved_percentage(player, achievement, progress_amount)
            if perc > 0
              perc_i = (perc * 100).to_i
              last_notified = player.progress_notified[achievement.title]
              if perc_i != last_notified
                send_progress player, achievement, perc_i
                notify_progress player, achievement, progress_amount, "25%", "a quarter of the way" if perc >= 0.25
                notify_progress player, achievement, progress_amount, "50%", "halfway" if perc >= 0.50
                notify_progress player, achievement, progress_amount, "75%", "you're almost" if perc >= 0.75
                player.progress_notified[achievement.title] = perc_i
              end
            end
          end
        end
      end
    end

    def self.quantity_by_method(player, method)
      respond_to?(method) ? send(method, player) : player.send(method)
    end

    def self.progress_by_method(player, method)
      respond_to?(method) ? send(method, player) : player.send(method)
    end

    def achieved?(player, achievement, progress)
      achieved_percentage(player, achievement, progress) >= 1.0
    end

    def achieved_percentage(player, achievement, progress)
      progress.to_f / (achievement.quantity_method ? self.class.quantity_by_method(player, achievement.quantity_method) : achievement.quantity)
    end

    def send_progress(player, achievement, progress)
      player.queue_message AchievementProgressMessage.new(achievement.title, progress)
    end

    def notify_progress(player, achievement, progress, short_progress_description, long_progress_description)
      hint_key = "#{achievement.title}-#{short_progress_description}"
      if !player.hints[hint_key]
        player.alert "You've #{achievement.notify.sub(/\*/, progress.to_s).sub(/s$/, progress == 1 ? '' : 's')} - #{long_progress_description} to the #{achievement.title} achievement!"
        player.ignore_hint hint_key
      end
    end

    def progress_all(player, quantity = 1)
      progress player, @achievements.values, quantity
    end

    def remaining_achievements(player)
      @achievements.reject{ |ach, config| player.has_achieved?(ach) }
    end

    def self.items_for_achievement(title)
      raise "Achievement '#{title}' not found" unless Game.config.achievements[title]

      Game.config.achievements[title].items.map{ |i| Game.item(i).code.to_s }
    end
  end

  def self.progress_summary(player)
    summary = {}

    Game.config.achievement_types.each do |type|
      clazz = "Achievements::#{type}".constantize

      Game.config.achievements_by_type(type).each do |name, config|
        # Use static quantity or quantity method
        quantity = config.quantity_method ? clazz.quantity_by_method(player, config.quantity_method) : config.quantity

        if quantity
          progress = nil
          if progress_key = config.progress
            progress = player.progress[progress_key]
          elsif progress_method = config.progress_method
            progress = clazz.progress_by_method(player, progress_method)
          end

          # Only add if progress percent is between 0 and 1
          if progress
            progress_percent = progress / quantity.to_f
            if progress_percent > 0 && progress_percent < 1.0
              summary[name] = (progress_percent * 100).to_i / 100.0
            end
          end
        end
      end
    end

    summary
  end

  def self.progress_summary_message(player)
    summary = progress_summary(player)
    summary.size > 0 ? AchievementProgressMessage.new(summary.map{ |name, progress| [name, (progress * 100).to_i] }) : nil
  end
end
