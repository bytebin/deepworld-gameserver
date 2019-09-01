module Behavior
  class Fly < Rubyhave::Behavior
    include TargetHelpers

    attr_accessor :random

    def on_initialize
      @random = true
      @blockable = @options['blockable'].nil? ? true : @options['blockable']
    end

    def behave
      if entity.position && target_point && raynext = zone.raynext(entity.position, target_point)
        move = Vector2.new(*raynext) - entity.position

        unless @blockable && blocked_move?(move)
          entity.move = move
          entity.animate @options['animation'] || 'fly'
          entity.speed = entity.base_speed * speed_multiplier
          entity.direction = (entity.move.x >= 0) ? 1 : -1

          return Rubyhave::SUCCESS
        end
      end

      clear(:target_point)
      return Rubyhave::FAILURE
    end

    def target_point
      get(:target_point) || (@random ? set(:target_point, random_point) : nil)
    end

    def speed_multiplier
      1
    end
  end
end
