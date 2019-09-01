# Reset player and return to spawn point

class RespawnCommand < BaseCommand
  data_fields :status

  def execute
    player.respawn!
  end
end