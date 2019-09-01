module Scenarios
  class HomeWorld < Base

    def player_event(player, event, data)
      case event
      when :entered
        player.queue_message EventMessage.new('uiHints', [])

        # Change zone teleporters to spawn teleporters if owner hasn't yet registered
        if player.owns_current_zone? && !player.registered?
          @zone.spawns_in_range(Vector2[0, 0], 9999999).each do |sp|
            @zone.update_block nil, sp.x, sp.y, FRONT, Game.item_code('mechanical/spawn-teleporter')
          end

          player.show_dialog Game.config.dialogs.home_world
        end

      # Convert spawn teleporters to zone teleporters after registration process
      when :spawn
        @zone.find_items(Game.item_code('mechanical/spawn-teleporter')).each do |sp|
          @zone.update_block nil, sp[0], sp[1], FRONT, Game.item_code('mechanical/zone-teleporter')
        end

      end
    end
  end
end