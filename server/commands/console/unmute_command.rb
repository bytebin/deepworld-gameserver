# Console command: mute
class UnmuteCommand < BaseCommand
  data_fields :player_name

  def execute
    if player_name == 'all'
      player.unmute_all!

    else
      Player.named(player_name, fields: [:name, :_id]) do |p|
        if p.nil?
          err = "Player '#{player_name}' not found"
        else
          player.unmute!(p)
        end
      end
    end
  end

  def validate
    @errors << "Player name cannot be blank." if player_name.blank?
  end

  def fail
    alert @errors.join(', ')
  end
end
