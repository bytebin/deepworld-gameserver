# Fly linearly in one direction of the target (a lame but workable pathfinding strategy)
# E.g., minimize x and y distance individually

module Behavior
  class FlySeek < Fly

    attr_accessor :direction

    def target_point
      @direction ||= :x
      @last_seek_change_at ||= Ecosystem.time
      if Ecosystem.time > @last_seek_change_at + 5.seconds
        @direction = @direction == :x ? :y : :x
        @last_seek_change_at = Ecosystem.time
      end

      pos = get_target_point

      if @direction == :x
        x_bump = pos.x > entity.position.x ? 1 : -1
        Vector2[pos.x + x_bump, entity.position.y.round]
      else
        y_bump = pos.y > entity.position.y ? 1 : -1
        Vector2[entity.position.x.round, pos.y + y_bump]
      end
    end

    def speed_multiplier
      1.25
    end

    def can_behave?
      has?(:target)
    end

  end
end
