# Console command: change team between red and blue
class TeamCommand < BaseCommand

  def execute
    if Deepworld::Env.development?
      alert "You can only change teams in Team PvP" unless zone.scenario == 'Team PvP'
      alert "You can only change teams once every five minutes." and return unless admin? || Time.now > player.last_changed_team_at + 5.minutes

      player.pvp_team = player.pvp_team == 'Red' ? 'Blue' : 'Red'
      player.change 'uni' => player.appearance_uniform, 'pvpg' => player.pvp_team
      player.last_changed_team_at = Time.now

      player.queue_peer_messages EntityStatusMessage.new(player.status(Entity::STATUS_EXITED))
      player.queue_peer_messages EntityStatusMessage.new(player.status)
      player.send_peers_pvp_team_message
      alert "You joined the #{player.pvp_team} team!"
    end
  end

end