module Npcs
  class Spawner
    attr_reader :zone

    # TODO: Use 'spawn' option in config.yml... group for string, names for regex

    def initialize(zone)
      @zone = zone
    end

    def max_entities
      if @zone.tutorial?
        6
      elsif @zone.static?
        @zone.chunk_count.clamp(0, 75)
      else
        (@zone.players.count * 8).clamp(0, 75)
      end
    end

    def spawn_entities
      Game.add_benchmark :spawn_entities do
        if should_spawn_entities?
          immediate = rand < 0.75
          chunk_indexes = (immediate ? self.zone.immediate_chunk_indexes.keys.random(2) : (self.zone.active_chunk_indexes.keys - self.zone.immediate_chunk_indexes.keys).random(2)).compact
          spawn_in_chunks chunk_indexes if chunk_indexes.size > 0
        end
      end
    end

    def should_spawn_entities?
      @zone.transient_mob_count < max_entities && @zone.players.any?{ |pl| Time.now < pl.last_used_inventory_at + 300 }
    end

    def spawn_entity(key, position)
      Npcs::Npc.new(key, @zone, position)
    end

    def spawn_block_entity(position, entity_key)
      entity = spawn_entity(entity_key, position)
      entity.block = position

      zone.add_entity entity
    end

    def spawning_patterns
      load_spawning_patterns unless @spawning_patterns
      @spawning_patterns
    end

    def load_spawning_patterns
      @spawning_patterns = Hashie::Mash.new(YAML.load_file(File.expand_path('../spawning.yml', __FILE__))[zone.biome])

      # Make sure these entities are defined in the game configuration
      @spawning_patterns = @spawning_patterns.select{|k,v| Game.config.entities.include?(k)}

      update_spawning_ratios
    end

    def update_spawning_ratios
      # Modify frequency based on difficulty level of zone
      difficulty = get_zone_difficulty

      @spawning_patterns.each_pair do |entity_name, entity_spawning|
        is_friendly = Game.entity(entity_name).friendly

        entity_spawning.frequency_original ||= entity_spawning.frequency
        entity_spawning.frequency = entity_spawning.frequency_original

        case difficulty
        when 1
          entity_spawning.frequency = 0 if !is_friendly
        when 2
          entity_spawning.frequency *= 2 if is_friendly
        when 3
          # No change
        when 4
          entity_spawning.frequency *= 2 if !is_friendly
        when 5
          entity_spawning.frequency *= 3 if !is_friendly
        end
      end
    end

    def get_zone_difficulty
      if setting = @zone.machine_setting('spawner', 'hostility')
        { 0 => 1, 1 => 3, 2 => 5 }[setting] || 3
      else
        @zone.difficulty
      end
    end

    def spawn_in_chunks(chunk_indexes, spawn_types = nil)
      spawn_types ||= [[5, 'maw'], [6, 'pipe']] # ugh... make configgy
      entities = []
      Chunk.many(@zone, chunk_indexes).each do |chunk|
        # Maw spawning
        if !suppress_maw_spawning? && self.zone.immediate_chunk_indexes.include?(chunk.index)
          spawn_type = spawn_types.random
          entities += spawn_in_blocks(chunk, chunk.query(spawn_type.first, nil, nil), spawn_type.last)

        # Open area spawning
        else
          unless @zone.tutorial? || suppress_area_spawning?
            entities += spawn_in_blocks(chunk, chunk.query(false, 0, 0), nil, 'sky')
            entities += spawn_in_blocks(chunk, chunk.query(true, 0, 0), nil, 'cave')
          end
        end
      end
      entities.compact
    end

    def suppress_maw_spawning?
      @zone.machine_setting('spawner', 'maw_spawning') == 1
    end

    def suppress_area_spawning?
      @zone.machine_setting('spawner', 'area_spawning') == 1
    end

    def spawn_in_blocks(chunk = nil, blocks = nil, orifice = nil, locale = nil)
      return [] if blocks.blank?

      # Bust open covered orifices
      if orifice
        blocks.select! do |b|
          pos = Vector2[b.first, b.last]

          # Bust back if possible, otherwise check front
          if !bust_orifice(pos, BACK)
            if !bust_orifice(pos, FRONT)
              # No back or front, so it's open for spawning
              true
            end
          end
        end
      end

      if blocks.size > 0
        block = blocks.random

        # Get all entities that could spawn in this chunk (based on spawning patterns)
        possible_entities = spawning_patterns.select do |entity, pattern|
          (orifice.nil? || pattern.orifice == orifice) &&
          (locale.nil? || pattern.locale == locale) &&
          chunk.origin.y >= (pattern.min_depth || 0) * zone.size.y &&
          chunk.origin.y <= (pattern.max_depth || 1.0) * zone.size.y &&
          (!pattern.purified || zone.purified?)
        end

        if possible_entities.present?
          # Pick a random entity based on frequency
          if entity_key = possible_entities.random_by_frequency
            pattern = possible_entities[entity_key]

            # Spawn entity
            count = pattern.group ? (pattern.group.first..pattern.group.last).random.to_i : 1
            return count.times.map do
              entity = spawn_entity(entity_key, Vector2[block.first, block.last])
              self.zone.add_entity entity
              entity
            end
          end
        end
      end

      []
    end

    def bust_orifice(position, layer)
      peek_data = self.zone.peek(position.x, position.y, layer)
      if peek_data[0] > 0
        if rand < 0.333
          item = Game.item(peek_data[0]).mod == 'decay' && peek_data[1] < 5 ? peek_data[0] : 0
          mod = item > 0 ? [peek_data[1] + 1, 2].max : 0
          self.zone.update_block nil, position.x, position.y, layer, item, mod
        end
        true
      else
        false
      end
    end
  end
end
