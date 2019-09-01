# Console command: remove a player from a guild
class GuildRemoveCommand < BaseCommand
  include GuildCommandHelpers

  data_fields :name

  def execute
    if name.downcase == player.name.downcase
      alert "You cannot remove yourself, try a /gquit command."
      return
    else
      Player.named(name) do |remove|
        if remove && remove.guild_id != player.guild_id
          alert "Sorry, #{name} does not belong to your guild."
        elsif remove
          player.guild.remove_member(remove, true)
        else
          alert "Player #{name} not found."
        end
      end
    end
  end

  def validate
    run_if_valid :validate_guild_member
    run_if_valid :validate_guild_owner
  end

  def fail
    alert @errors.join(', ')
  end
end
