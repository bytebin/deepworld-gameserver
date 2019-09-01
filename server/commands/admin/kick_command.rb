class KickCommand < BaseCommand
  admin_required
  data_fields :other_player_name, :zone_name

  def execute
    @zone_name = zone.name unless @zone_name.present?

    Zone.where(name: @zone_name).callbacks(false).first do |zone|
      if zone
        @other_player.send_to zone.id, true
      else
        error_and_notify "Couldn't find zone #{@zone_name}"
      end
    end
  end

  def validate
    @other_player = zone.find_player(@other_player_name) || zone.find_player(@other_player_name.gsub(/_/, ' '))
    error_and_notify "Couldn't find player #{@other_player_name}" unless @other_player
  end
end