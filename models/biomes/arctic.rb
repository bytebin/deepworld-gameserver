module Biomes
  class Arctic

    def initialize(zone)
      @zone = zone
    end

    def load
      @zone.acidity = 0
    end

    def step(delta_time)
    end

  end
end