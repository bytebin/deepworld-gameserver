module Behavior
  class EruptionAttack < Rubyhave::Behavior
    DIRECTION_VECTORS = {
      0 => [0, -1],
      1 => [1, 0],
      2 => [0, 1],
      3 => [-1, 0]
    } unless defined? DIRECTION_VECTORS

    def on_initialize
      @speed = @options['speed'] || 8
      @range = @options['range'] || 10
      @burst = @options['burst'] if @options['burst']
      @frequency = @options['frequency'] || 1
    end

    def behave(params = {})
      spawn = Npcs::Npc.new(@options['entity'], zone, entity.position)
      spawn.details = { '<' => entity.entity_id, '>' => target, '*' => true, 's' => @speed }
      spawn.details['#'] = @burst if @burst

      zone.add_client_entity spawn, entity
    end

    def target
      target = Vector2.new(*self.direction) * @range + entity.position
      zone.raycast(entity.position, target) || target.to_a
    end

    def direction
      return @direction if @direction

      if entity.block
        mod = zone.peek(*entity.block, FRONT)[1]
        @direction = DIRECTION_VECTORS[mod]
      end

      @direction ||= DIRECTION_VECTORS[0]
    end

    def can_behave?(params = {})
      Ecosystem.time > @start_at && !behaved_within?(1.0 / @frequency)
    end
  end
end
