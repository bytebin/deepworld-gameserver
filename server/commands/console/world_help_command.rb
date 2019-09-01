# Console command: display help screen for world commands
class WorldHelpCommand < BaseCommand
  include WorldCommandHelpers

  def execute
    if player.v3?
      player.show_dialog Game.config.dialogs.world_help
    else
      notify(Game.config.dialogs.world_help, 1)
    end
  end

  def validate
    run_if_valid :validate_owner
  end

  def fail
    alert @errors.join(', ')
  end
end
