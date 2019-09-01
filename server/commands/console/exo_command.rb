class ExoCommand < BaseCommand

  def execute
    player.show_dialog Game.config.dialogs.exo, true do |values|
      player.change_appearance_options('fg' => values[0] == 'Visible', 'to' => values[1] == 'Visible', 'lo' => values[2] == 'Visible')
    end
  end

end
