module Items
  module WorldMachines
    class Spawner < Items::WorldMachines::Base

      def dialog_type
        'spawner'
      end

      def update!
        @zone.spawner.update_spawning_ratios
      end

    end
  end
end