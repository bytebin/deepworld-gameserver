module Dynamics
  class Invasion

    attr_reader :last_invasion_at

    def initialize(zone)
      @zone = zone
      @invader_types = zone.biome == 'brain' ? { 'brains/small' => 15, 'brains/medium' => 2, 'brains/medium-dire' => 1 } :
        { 'revenant' => 15, 'dire-revenant' => 2, 'revenant-lord' => 1 }
      @current_invaders = []
    end

    def invade!(player)
      @last_invasion_at = Time.now

      # Kill old invaders
      @current_invaders.each do |i|
        if invader = @zone.ecosystem.find(i)
          invader.fx_teleport!
          invader.die!
        end
      end
      @current_invaders.clear

      # Spawn new invaders
      spawn_brain player.position
      EM.add_timer((3..4).random) do
        unless player.disconnected
          spawn_brain player.position
          EM.add_timer((1..2).random) do
            unless player.disconnected
              spawn_brain player.position
              EM.add_timer((0.5..1.5).random) do
                unless player.disconnected
                  spawn_brain player.position
                  if rand < 0.5
                    EM.add_timer((0..1).random) do
                      unless player.disconnected
                        spawn_brain player.position
                        spawn_brain player.position if rand < 0.5
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def spawn_brain(near_position)
      entity_type = @invader_types.random_by_frequency

      spots = (-3..3).inject([]) do |arr, x|
        (-3..3).each do |y|
          arr << Vector2[near_position.x + x, near_position.y + y]
        end
        arr
      end

      spots.select!{ |spot| @zone.peek(spot.x, spot.y, FRONT)[0] == 0 }
      if spots.present?
        random_spot = spots.sample
        ent = @zone.spawn_entity(entity_type, random_spot.x, random_spot.y, nil, true)
        @current_invaders << ent.entity_id
      end
    end

  end
end
