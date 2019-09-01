class MuteCommand < BaseCommand
  data_fields :player_name
  optional_fields :duration, :should_notify

  def execute
    dur = duration ? duration.to_i : nil

    if player_name == 'all'
      player.mute_all! dur

    else
      if pl = zone.find_player(player_name)
        player.mute! pl, dur, !!should_notify
      else
        alert "Player '#{player_name}' not found"
      end
    end
  end

  def validate
    @errors << "Player name cannot be blank." if player_name.blank?
    @errors << "Duration must be between 1 and 9999 minutes" if duration && !(1..9999).include?(duration.to_i)
  end

  def fail
    alert @errors.join(', ')
  end
end
