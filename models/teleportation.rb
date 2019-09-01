class Teleportation
  def self.spawn!(player)
    player.event! :spawn, nil if player.zone
    player.send_to(nil)
  end
end
