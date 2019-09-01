class ReportCommand < BaseCommand
  data_fields :player_name

  def execute
    Player.named(player_name, fields: [:name, :_id]) do |p|
      if p.nil?
        alert "Player '#{player_name}' not found"
      else
        player.report! p
      end
    end
  end

  def validate
    # Only allow veteran-ish players to report
    @errors << "Please use the /mute command if a player is bothering you." unless player.orders && player.orders.values.any?{ |o| o >= 1 }

    # Don't let players with no_report role to report
    @errors << "Sorry, your report priveleges have been revoked." if player.role?('no_report')

    # Don't report self
    @errors << "You cannot report yourself." if player_name.downcase == player.name.downcase
  end

  def fail
    alert @errors.join(', ')
  end
end
