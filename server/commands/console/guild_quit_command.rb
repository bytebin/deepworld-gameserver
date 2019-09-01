# Console command: remove yourself from your guild
class GuildQuitCommand < BaseCommand
  include GuildCommandHelpers
  require_confirmation do |cmd|
    "This will remove you from the #{cmd.player.guild.name} guild. Are you sure?"
  end

  def execute
    player.guild.remove_member(player)
  end

  def validate
    run_if_valid :validate_guild_member
    run_if_valid :validate_not_leader
  end

  def validate_not_leader
    if player.guild.leader? player.id
      @errors << "You'll need to designate a new guild leader before quitting."
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
