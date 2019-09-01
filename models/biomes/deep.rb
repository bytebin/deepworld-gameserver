module Biomes
  class Deep

    def initialize(zone)
      @zone = zone
      @steps = 0
    end

    def load
      @pipe_item_code = Game.item_code('base/pipe')
      @plugged_pipe_item_code = Game.item_code('base/pipe-plugged')

      @pipes = @zone.find_items(@pipe_item_code, BASE)
      @plugged_pipes = @zone.find_items(@plugged_pipe_item_code, BASE)

      @indexed_pipes = (@pipes + @plugged_pipes).inject({}) do |hash, pipe|
        idx = @zone.chunk_index(pipe[0], pipe[1])
        hash[idx] ||= []
        hash[idx] << pipe
        hash
      end
    end

    def step(delta_time)
      burst_pipes if @zone.acidity > 0.01
      @steps += 1
    end

    def burst_pipes
      Game.add_benchmark :burst_pipes do
        if !@possible_pipes || @steps % 3 == 0
          @possible_pipes = @zone.immediate_chunk_indexes.keys.inject([]){ |arr, idx| arr += @indexed_pipes[idx] || []; arr }
        end
        max_pipes = (@zone.immediate_chunk_indexes.size * 0.1).to_i.clamp(2, 50)
        pipes = @possible_pipes.random(max_pipes)
        pipes.each { |pipe| burst_pipe pipe }
      end
    end

    def burst_pipe(position)
      if rand < 0.125
        covered = false
        base, back, back_mod, front = @zone.all_peek(position.x, position.y)

        # Unplug if necessary
        if base == @plugged_pipe_item_code
          @zone.update_block nil, position.x, position.y, BASE, @pipe_item_code
          covered = true
        end

        # Kill blocks above pipe
        if front > 0
          @zone.update_block nil, position.x, position.y, FRONT, 0
          covered = true
        end
        if back > 0
          @zone.update_block nil, position.x, position.y, BACK, 0
          covered = true
        end

        # Explode a little
        y_perc = position.y / @zone.size.y.to_f
        damage = 4.0.lerp(10.0, y_perc)
        bomb = covered || rand < (y_perc * 0.125)
        @zone.explode Vector2[position.x, position.y], 4, nil, false, damage, bomb ? ['crushing', 'acid'] : ['acid'], bomb ? 'bomb' : 'poison', [0], skill: ['survival', -0.5]
      end
    end

  end
end