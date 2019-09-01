module Items
  module WorldMachines
    class Teleport < Items::WorldMachines::Base

      def menu!(option)
        case option
        when 'deactivate_natural_teleporters'
          @player.confirm_with_dialog 'Are you sure?' do
            deactivate_natural_teleporters!
          end
        end
      end

      def dialog_type
        'teleport'
      end

      def deactivate_natural_teleporters!
        @zone.indexed_meta_blocks[:teleporter].values.each do |tele|
          unless tele.player?
            @zone.update_block nil, tele.x, tele.y, FRONT, 0, 0
          end
        end

        @player.alert 'Natural teleporters destroyed!'
      end

    end
  end
end