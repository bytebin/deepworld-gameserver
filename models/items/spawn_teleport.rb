module Items
  class SpawnTeleport < Base

    def use(params = {})
      # Change spawn teleport to a zone teleport if player owns zone
      if @player.owns_current_zone?
        @zone.update_block nil, @position.x, @position.y, FRONT, Game.item_code('mechanical/zone-teleporter'), 0, @player
      end

      @player.show_dialog Game.config.dialogs.spawn_teleport, true do
        Teleportation.spawn!(@player)
      end
    end
  end
end
