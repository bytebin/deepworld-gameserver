#(start_zone 'Redgorge').growth_step!
module Dynamics
  class Growth

    attr_accessor :cycles

    def initialize(zone)
      @zone = zone
      @growth = ZoneKernel::Growth.new(@zone.kernel)
      @cycles = 0
    end

    def step!(cycles = 1)
      return unless sources.present? && cycles.to_i > 0

      # Decrease cycles and increase growth chance if more than one cycle
      cycle_mod = [cycles, 10].min
      cycles = cycles / cycle_mod if cycle_mod > 1

      bench_c = bench_rb = 0

      cycles.to_i.times do
        begin
          # Get growables
          growables = []
          bench_c += Benchmark.measure do
            growables = @growth.growables
          end.real

          bench_rb += Benchmark.measure do
            growables.each do |x, y, item, seed, seed_mod|
              if pattern = sources[item.to_s]
                if seed_config = items[seed.to_s]
                  grow_item(x, y, pattern, seed, seed_mod, seed_config, cycle_mod)
                else
                  plant_item(x, y, pattern, seed)
                end
              end
            end
          end.real
        rescue Exception => e
          Game.info error: "Growth step exeception", zone_id: @zone.id
          raise if Deepworld::Env.test? || Deepworld::Env.development?
        end

        @cycles += 1
      end

      Game.add_benchmark :growth_step_c, bench_c
      Game.add_benchmark :growth_step_rb, bench_rb
    end

    def grow_item(x, y, pattern, seed, current_mod, item, chance_multiplier = 1)
      if current_mod < item['max_mod']
        if should_grow?(item['chance'] * chance_multiplier)
          new_mod = current_mod + 1
          @zone.update_block nil, x, y - 1, FRONT, seed, new_mod

          # If replace_seed is set, change the seed item on the final grow step
          if new_mod == item['max_mod']
            if replace_seed = pattern['0'][seed.to_s]['replace_seed']
              @zone.update_block nil, x, y, FRONT, Game.item_code(replace_seed)
            end
          end
        end
      end
    end

    def plant_item(x, y, pattern, seed)
      return unless y > 0 && pat = pattern[seed.to_s]

      owner = @zone.block_owner(x, y, FRONT)
      @zone.update_block(nil, x, y - 1, FRONT, pat.random_by_frequency.to_i, 0, owner)
    end

    def fertilize!(position)
      if position.y < @zone.size.y - 1
        seed = @zone.peek(position.x, position.y + 1, FRONT)[0]
        if pattern = sources[seed.to_s]
          plant_opts = pattern['0']
          if plant_opts
            if plant = plant_opts.random_by_frequency
              if plant_config = items[plant.to_s]
                @zone.update_block nil, position.x, position.y, FRONT, plant.to_i, plant_config['max_mod']
                if replace_seed = pattern['0'][plant.to_s]['replace_seed']
                  @zone.update_block nil, position.x, position.y + 1, FRONT, Game.item_code(replace_seed)
                end
                return true
              end
            end
          end
        end
      end
      false
    end

    def growth_data
      @growth_data ||= YAML.load_file(File.expand_path('../growth.yml', __FILE__)).freeze
    end

    def items
      @items ||= Game.code_keys(growth_data['items']).freeze
    end

    def sources
      return @sources if @sources

      if growth_data['biomes'][@zone.biome]
        @sources = Game.code_keys(growth_data['biomes'][@zone.biome])
        @sources.each_pair do |seed,items|
          items.each_pair do |item, v|
            items[item.to_s] = Game.code_keys(v)
          end
          @sources[seed] = Game.code_keys(items)
        end
      else
        @sources = {}
      end

      @sources
    end

    def should_grow?(chance)
      rand < (chance || 1)
    end
  end
end
