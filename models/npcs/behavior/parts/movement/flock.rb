#http://processing.org/learning/topics/flocking.html
module Behavior
  class Flock < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @range = @options['range'] || 20
      @tries = 0
    end

    def behave(params = {})
      set_target

      if target = get(:target)
        return flock_toward(target)
      else
        return Rubyhave::FAILURE
      end
    end

    def set_target
      if has?(:target)
        clear_defunct_target
        clear(:target) if rand(9) == 1
      end

      unless has?(:target)
        # Only try occasionally
        if rand(6) == 1
          # Gradually step up range after several tries
          range = [@range, @range / 4 * (@tries+1)].min

          # If target acquired, reset tries count
          if target = closest_npc(range, entity.ilk)
            set :target, target
            @tries = 0
          else
            @tries += 1
          end
        end
      end
    end

    def clear_defunct_target
      if target = get(:target)
        if target_dead?(target) || !target_in_range?(target, @range) || !target_visible?(target)
          clear(:target)
        end
      end
    end

    def flock_toward(target)
      # Anticipate target position (with randomization)
      pos = (target.position + target.velocity).fixed
      pos += Vector2.new(rand(11) - 5, rand(11) - 5)

      if raynext = zone.raynext(entity.position, pos)
        move = Vector2.new(*raynext) - entity.position

        unless blocked_move?(move)
          entity.move = move
          entity.animate @options['animation'] || 'fly'
          entity.speed = entity.base_speed
          entity.direction = (entity.move.x >= 0) ? 1 : -1

          return Rubyhave::SUCCESS
        end
      end

      return Rubyhave::FAILURE
    end

    def can_behave?(params = {})
      zone.peek(*entity.position, BASE)[0] == 0 # Only above ground
    end
  end
end
