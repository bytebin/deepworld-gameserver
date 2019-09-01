# Console command: switch a guild leader
class GuildLeaderCommand < BaseCommand
  include GuildCommandHelpers
  require_confirmation do |cmd|
    "This will revoke your #{cmd.player.guild.name} guild leadership and make you a guild member. Are you sure?"
  end

  data_fields :name

  def execute
    Player.named(name) do |invitee|
      if invitee.nil?
        alert "Player #{name} not found."
      elsif invitee.guild_id && invitee.guild_id != player.guild.id
        alert "Sorry, #{name} already belongs to a guild."
      elsif (invitee = zone.find_player_by_id(invitee.id)) && player.guild.near_obelisk(player) && player.guild.near_obelisk(invitee)
        player.guild.offer_leadership(invitee)
        alert "#{name} has been invited to LEAD the \"#{player.guild.name}\" guild."
      else
        alert "Please meet #{name} at the guild obelisk to pass leadership."
      end
    end
  end

  def validate
    run_if_valid :validate_guild_member
    run_if_valid :validate_guild_owner
    run_if_valid :validate_names_set
  end

  def fail
    alert @errors.join(', ')
  end
end
