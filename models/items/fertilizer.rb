module Items
  class Fertilizer < Base

    def use(params = {})
      @zone.growth.fertilize! @position
    end

  end
end