module Behavior
  module TargetHelpers

    def self.included(base)

      # Conditions

      def target_dead?(target)
        !target_alive?(target)
      end

      def target_alive?(target)
        !!target.try(:alive?)
      end

      def target_in_range?(target, range)
        Math.within_range?(target.position, entity.position, range)
      end

      def target_visible?(target)
        zone.raycast(entity.position, target.position).nil? ||
        (target.position.y > 0 && zone.raycast(entity.position, target.position + Vector2[0, -1]).nil?)
      end

      def target_acquirable?(target, range = nil, require_visibility = false)
        target_alive?(target) &&
          (!range || target_in_range?(target, range)) &&
          (!require_visibility || target_visible?(target)) &&
          target.can_be_targeted?(entity)
      end

      def get_target_point
        get(:target).is_a?(Vector2) ? get(:target) : get(:target).position
      end

      def can_reach?(position, range)
        Math.within_range?(entity.position, position, range) && zone.raycast(entity.position, position).nil?
      end

      def can_reach_directed_target?(range = 2)
        target = get(:directed_blocks).try(:first)
        set :target, target
        target && can_reach?(target, @reach || 2)
      end

      def point_towards(origin, destination)
        pt = Vector2[0, 0]
        if destination.x > origin.x
          pt.x += 1
        elsif destination.x < origin.x
          pt.x -= 1
        end
        if destination.y > origin.y
          pt.y += 1
        elsif destination.y < origin.y
          pt.y -= 1
        end
        zone.in_bounds?(origin.x + pt.x, origin.y + pt.y) ? pt : Vector2[0, 0]
      end


      # Ecosystem

      def random_player(range)
        zone.players_in_range(entity.position, range).select{ |p| p.can_be_targeted? }.randomized.detect do |player|
          target_visible? player
        end
      end

      def enemy_target(range, owner)
        zone.players_in_range(entity.position, range).select{ |p| p.can_be_targeted? }.randomized.detect do |player|
          target_visible?(player) && (!owner || (player.id != BSON::ObjectId(owner) && !player.followers.include?(BSON::ObjectId(owner))))
        end
      end

      def random_point(max_distance = 30, min_distance = 10)
        distance = (rand * ((max_distance + 1) - min_distance)).to_i + min_distance
        entity.position + Vector2.new_polar(rand(3.1415*2), distance)
      end

      def closest_npc(range, ilk, exact = false)
        closest = nil
        b = Benchmark.measure do
          npcs = zone.npcs_in_range(entity.position, range, {ilk: ilk}) - [entity]

          if npcs
            sorted_npcs = npcs.map{ |npc|
                vec = (entity.position - npc.position)
                [npc, exact ? vec.magnitude : vec.x.abs + vec.y.abs]
            }.sort_by{ |npca| npca[1] }

            closest = sorted_npcs.detect{ |npca| target_visible? npca[0] }
            closest = closest[0] if closest
          end
        end

        entity.zone.increment_benchmark :closest_npc, b.real
        closest
      end
    end
  end
end