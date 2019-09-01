# Console command: display help screen for guild commands
class GuildHelpCommand < BaseCommand
  include GuildCommandHelpers

  def execute
    dialog = player.guild.leader?(player.id) ? 'guild_owner_help' : 'guild_member_help'
    notify(Game.config.dialogs[dialog], 1)
  end

  def validate
    run_if_valid :validate_guild_member
  end

  def fail
    alert @errors.join(', ')
  end
end
