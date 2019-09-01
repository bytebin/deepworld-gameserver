module Dynamics
  class Science

    def initialize(zone)
      @zone = zone
      Prefab.find_all(type: 'science') do |prefabs|
        @prefabs = prefabs
      end
    end

  end
end