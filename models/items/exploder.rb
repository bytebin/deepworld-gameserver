module Items
  class Exploder < Base

    def use(params = {})
      return if @zone.suppress_spawners || ((@zone.time_ticks[:exploder] || 0) > 1)

      # Get explosion type
      explosion = (@meta['e'] || 'fire').downcase

      # Explode!
      @zone.explode @position + Vector2[0.5, -0.5], 6, Triggerer.new(@player), false, 6, [explosion], "bomb-#{explosion}"

      @zone.time_ticks[:exploder] ||= 0
      @zone.time_ticks[:exploder] += 1/30.0
    end

    def validate(params = {})
      require_interval(3) && require_mod(1)
    end
  end

  class Triggerer
    attr_accessor :entity

    def initialize(ent)
      @entity = ent
    end

    def player
      @entity
    end

    def grant_xp?(type)
      false
    end

    def method_missing(method, *args)
      @entity.send(method, *args) if @entity
    end

  end

end