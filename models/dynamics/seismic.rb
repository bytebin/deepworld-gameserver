module Dynamics
  class Seismic

    def initialize(zone)
      @zone = zone
      @next_earthquake_at = Time.now + (earthquake_interval * rand)
      @current_earthquake = 0
      @earth = Game.item_code('ground/earth')
      @dug_earth = Game.item_code('ground/earth-dug')
    end

    def step!(delta)
      # Don't run earthquakes in static or owned zones
      return if @zone.static? || @zone.owned?

      # Start new earthquake if it's time
      if Time.now > @next_earthquake_at
        # Only start earthquake if we find a position
        if pos = earthquake_position
          earthquake! pos
        end

        @next_earthquake_at = next_earthquake_at
      end

      # Decrement earthquake time and send messages as we move past the seconds
      @current_earthquake -= delta
      send_message if @current_earthquake > 0 && @current_earthquake.to_i < (@current_earthquake+delta).to_i

      # Do some damage
      if @current_earthquake > 1.5 && @current_earthquake_position
        Game.add_benchmark :earthquake_damage do
          8.times do
            range = 200
            pos = @current_earthquake_position + Vector2[rand(range*2) - range, rand(range*2) - range]
            damage pos
          end
        end
      end
    end

    def earthquake!(position)
      @current_earthquake_position = position
      @current_earthquake = earthquake_duration
    end

    def earthquake_duration_left
      [@earthquake_duration - (Time.now - @earthquake_at), 0].max
    end

    def next_earthquake_at
      Time.now + earthquake_interval + @current_earthquake.to_i.seconds
    end

    def earthquake_interval
      (30..45).random.minutes
    end

    def earthquake_duration
      (30..40).random.seconds
    end

    # Find random earthquake position
    def earthquake_position
      pos = @zone.random_point
      pos.y = [pos.y, 250].max # Don't have earthquakes in the air
      pos
    end

    def send_message
      if @current_earthquake_position
        @zone.queue_message EffectMessage.new(
          @current_earthquake_position.x * Entity::POS_MULTIPLIER,
          @current_earthquake_position.y * Entity::POS_MULTIPLIER,
          'earthquake',
          @current_earthquake.ceil.to_i
        )
      end
    end

    def damage(position)
      if chunk = @zone.chunk_at_position(position)
        # Fill in dug blocks
        chunk.query(true, nil, @dug_earth).each do |block|
          @zone.update_block nil, block[0], block[1], FRONT, self.fill_item if rand < 0.5
        end

        # Fill in underground
        fill_in = @zone.kernel.earth_query(chunk.index, true, 0, true)
        fill_in.each do |block|
          @zone.update_block nil, block[0], block[1], FRONT, @dug_earth if rand < 0.3
        end

        if rand < 0.3
          # Kill orifice plugs
          if false
            orifice_types = [7, 8]
            orifice_types.each do |o|
              orifices = chunk.query(o, nil, nil)
              if orifices.present?
                orifices.each do |orifice|
                  @zone.update_block nil, orifice.first, orifice.last, BASE, o - 2 if rand < 0.3
                end
              end
            end
          end

          # Spawn extra entities in chunk
          @zone.spawner.spawn_in_chunks [chunk.index] if rand < 0.5
        end
      end
    end

    def fill_item
      if rand < 0.0345
        r = rand
        if r < 0.25
          @clay ||= (1..5).map{ |c| Game.item_code("ground/clay-#{c}") }
          @clay.random
        elsif r < 0.5
          @root ||= Game.item_code('ground/earth-root-1')
        elsif r < 0.75
          @rock ||= Game.item_code('ground/earth-rock')
        else
          @ore ||= %w{copper iron zinc quartz}.map{ |i| Game.item_code("ground/#{i}") }
          @ore.random
        end
      else
        @earth
      end
    end

    def simulate!(time)
      quakes = time / earthquake_interval / 10
      b = Benchmark.measure do
        quakes.to_i.times do
          earthquake! earthquake_position
          steps = earthquake_duration.to_i / 2
          steps.times do
            step! 1.0
          end
        end
      end
    end

  end
end
