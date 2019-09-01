module Items
  class DailyBonus < Base

    # Sample player data:
    #
    # time_zone = "-04:00"

    MAX_MULTIPLIER = 5
    MINIMUM_PLAY_TIME = 15.minutes

    def use(params = {})
      @ref = params[:ref]
      @player.daily_bonus ||= {}
      @character_name = params[:character_name]

      if daily_bonus_ready?
        if time_played_since_last_bonus.nil? || time_played_since_last_bonus > MINIMUM_PLAY_TIME
          msg = Game.config.dialogs.daily_bonus.ready
          apply_daily_bonus msg
        else
          time_left = ((MINIMUM_PLAY_TIME - time_played_since_last_bonus) / 60.0).ceil.to_i.to_s
          timer = Game.config.dialogs.daily_bonus.not_enough_play_timer.sub(/\$\$/, time_left)
          @player.show_dialog dialog(Game.config.dialogs.daily_bonus.not_enough_play) + [{ 'text' => ' ' }, { 'text' => timer, 'text-color' => '444444' }], false
        end
      else
        @player.show_dialog dialog(Game.config.dialogs.daily_bonus.not_ready), false
      end
    end

    def dialog(msg)
      [{ 'title' => @character_name }, { 'text' => msg }]
    end

    def apply_daily_bonus(message = nil)
      multiplier = daily_bonus_multiplier
      multiplier = 1 if multiplier > MAX_MULTIPLIER

      loot_level = [@player.adjusted_skill('luck'), multiplier == MAX_MULTIPLIER ? 10 : multiplier].min
      loot_types = [['resources'], ['resources'], ['resources'], ['resources', 'treasure', 'armaments']][multiplier - 1] || ['treasure+', 'armaments+']
      Rewards::Loot.new(@player, level: loot_level, types: loot_types, message: message ).reward!

      data['mult'] = multiplier
      data['ref'] = @ref
      data['last'] = Time.now.utc
      data['last_pt'] = @player.play_time
      save_data!
    end

    def days_since_last_bonus
      if data['last']
        tz = @player.time_zone.to_i
        last_day = (data['last'] + tz.hours).yday
        today = (Time.now.utc + tz.hours).yday
        today < last_day ? today + Time.new(data['last'].year, 12, 31).yday - last_day : today - last_day
      else
        nil
      end
    end

    def time_played_since_last_bonus
      data['last_pt'] ? @player.play_time - data['last_pt'] : nil
    end

    def daily_bonus_ready?
      data.blank? || data['last'].blank? || (days_since_last_bonus && days_since_last_bonus > 0)
    end

    def daily_bonus_multiplier
      if !data || !data['mult'] || @ref != data['ref'] || (days_since_last_bonus && days_since_last_bonus > 1)
        1
      else
        data['mult'] + 1
      end
    end

    def data
      @player.daily_bonus
    end

    def save_data!
      @player.update daily_bonus: data
    end

  end
end