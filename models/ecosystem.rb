class Ecosystem
  PROFILE_BEHAVIOR = false

  @@time = 0
  attr_accessor :behave_all, :debug
  attr_reader :players, :npcs, :npcs_by_ilk, :entities, :characters, :last_behave_count

  def self.time
    @@time
  end

  def initialize(zone)
    @@time              = Time.now
    @zone               = zone
    @entity_lock        = Mutex.new
    @next_entity_id     = 0

    # =============================
    # Lookups
    # =============================
    @npcs               = []
    @npcs_by_ilk        = {}

    error_proc = Deepworld::Env.development? ? Proc.new{ |err| p err } : nil

    spatial_hash_sz = Vector2[50, 50]
    @player_spatial_hash = SpatialHash.new(spatial_hash_sz, @zone.size, error_proc)
    @npc_spatial_hash = SpatialHash.new(spatial_hash_sz, @zone.size, error_proc)

    @players            = []
    @entities           = {}
    @characters         = {}

    @spawner_queue      = []
    @spawner_queue_lock = Mutex.new
    @players_lock       = Mutex.new

    EM.next_tick { initialize_entities }
  end

  def step!
    Game.add_benchmark :ecosystem_step do
      clear_entities
      process_scheduled_spawners
      Game.add_benchmark :spatial_hash_reindex do
        @player_spatial_hash.reindex
        @npc_spatial_hash.reindex
      end
    end
  end

  def spawn_entity(entity_type, x, y, character = nil, effect = nil, ephemeral = false)
    if @zone.in_bounds?(x, y)
      cfg = Game.entity(entity_type) || Game.entity_by_code(entity_type)
      if cfg && cfg.code
        entity = Npcs::Npc.new(entity_type, @zone, Vector2.new(x, y))
        entity.ephemeral = ephemeral
        if character
          entity.character = character
          entity.name = character.name
          entity.set_details 'job' => character.job
          character.entity = entity
        end
        add_entity entity

        # Effect
        if effect
          pos = Vector2[x + 0.5, y + 0.5]
          pos += effect if effect.is_a?(Vector2)
          @zone.queue_message EffectMessage.new(pos.x * Entity::POS_MULTIPLIER, pos.y * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)
        end

        return entity
      end
    end

    false
  end

  def add_entity(entity)
    entity.zone = @zone
    entity.entity_id = next_entity_id!

    if entity.player?
      entity.zone_changed!
      @players_lock.synchronize { @players << entity }
      @player_spatial_hash << entity
    else
      @npcs << entity
      @npcs_by_ilk[entity.ilk] ||= []
      @npcs_by_ilk[entity.ilk] << entity
      @npc_spatial_hash << entity
    end

    entity.after_add

    @entities[entity.entity_id] = entity
    @characters[entity.entity_id] = entity if entity.character

    entity
  end

  def add_client_entity(entity, from_entity = nil)
    # Drop entity status messages, since they dont get added to entities collection
    msg = EntityStatusMessage.new(entity.status)

    if from_entity
      from_entity.queue_tracked_messages msg
    else
      players_in_range(entity.position, Deepworld::Settings.player.entity_radius).each do |player|
        player.queue_message msg
      end
    end
  end

  def remove_entity(entity)
    if entity.player?
      @players_lock.synchronize { @players.delete entity }
      @player_spatial_hash.delete entity
    else
      @npcs.delete entity
      @npcs_by_ilk[entity.ilk].delete entity
      @npc_spatial_hash.delete entity
      entity.cleared = true
      entity.queue_tracked_messages EntityStatusMessage.new(entity.status(Entity::STATUS_EXITED))
    end

    @entities.delete(entity.entity_id)
    @characters.delete(entity.entity_id) if entity.character

    # If entity was a guard, remove guard code from meta block if still there (so guard doesn't spawn next zone spinup)
    if entity.guard
      if meta = @zone.get_meta_block(entity.guard.x, entity.guard.y)
        meta.remove_guard entity.code
      end
    end
  end

  def change_entity(entity, details = {})
    entity.set_details details

    @players.each do |p|
      if p.tracking_entity?(entity.entity_id)
        p.queue_message EntityChangeMessage.new([[entity.entity_id, details]])
      end
    end
  end



  # =============================
  # Queries
  # =============================
  def entities_in_range(position, range, options = nil)
    players_in_range(position, range) + npcs_in_range(position, range, options)
  end

  def players_in_range(position, range)
    return [] unless position && range
    @player_spatial_hash.items_near(position, range)
  end

  def npcs_in_range(position, range, options = nil)
    @last ||= Time.now
    return [] unless position && range
    @npc_spatial_hash.items_near(position, range, true, options ? options[:ilk] : nil)
  end

  def npcs_in_range_old(position, range, options = nil)
    npcs = []

    b = Benchmark.measure do
      if options && options[:ilk]
        if @npcs_by_ilk[options[:ilk]]
          npcs = @npcs_by_ilk[options[:ilk]].select do |npc|
            Math.within_range?(npc.position, position, range)
          end
        else
          npcs = []
        end
      else
        npcs = @npcs.select do |npc|
          Math.within_range?(npc.position, position, range)
        end
      end
    end

    @zone.increment_benchmark :npcs_in_range, b.real
    npcs
  end

  def npcs_at_position(position)
    @npc_spatial_hash.items_near(position, 1).select{ |n| n.position == position }
  end

  def find(entity_id)
    @entities[entity_id]
  end

  def find_player(player_name)
    player_name = player_name.downcase
    @players.detect { |p| p.name.downcase == player_name }
  end

  def find_player_by_id(player_id)
    @players.detect { |p| p.id.to_s == player_id.to_s }
  end

  def moved_entity_positions(entity_ids = nil)
    ents = entity_ids ? @entities.values_at(*entity_ids) : @entities.values
    ents.select! do |e|
      e.present? &&
      e.health > 0 &&
      (e.last_moved_at.nil? || (Time.now - e.last_moved_at) < 0.25 || e.character.try(:job) == "quester")
    end
    ents.map(&:position_array).compact
  end

  def all_entity_positions(entity_ids = nil)
    ents = entity_ids ? @entities.values_at(*entity_ids) : @entities.values
    ents.select!{ |e| e.present? && e.health > 0 }
    ents.map(&:position_array).compact
  end

  def mob_count
    self.npcs.count{ |npc| npc.mobile? && !npc.guard? }
  end

  def transient_mob_count
    self.npcs.count{ |npc| npc.mobile? && !npc.guard? && !npc.character? }
  end

  def clear_entities
    @npcs.each do |npc|
      if npc.clearable?
        remove_entity npc
      end
    end
  end

  # Process behavior trees on entities (if they're ready for next step)
  def behave_entities(delta_time)
    return if Time.now < @zone.frozen_until
    @@time = Time.now

    behave_count = 0

    Game.add_benchmark :behave_entities do

      # Old busted
      if false
        active_chunk_hash = @zone.active_chunk_indexes

        @npcs.each do |npc|
          if npc.servant? || (active_chunk_hash[npc.chunk_index] || behave_all)
            behaved = npc.behave!
            behave_count += 1 if behaved
          end
        end

      # New hotness
      else
        @active_chunk_hash ||= @zone.active_chunk_indexes
        @npcs_behaving ||= @npcs.dup
        @npcs_behaving_idx ||= 0

        step = Time.now.to_f
        max_step = delta_time * 0.5
        min_behave = @npcs_behaving.size / 100 * 2

        while @npcs_behaving_idx < @npcs_behaving.size
          npc = @npcs_behaving[@npcs_behaving_idx]
          if npc.alive? && (npc.servant? || (@active_chunk_hash[npc.chunk_index] || behave_all))
            behaved = npc.behave!
            behave_count += 1 if behaved
          end
          @npcs_behaving_idx += 1

          break if behave_count > min_behave && (Time.now.to_f - step > max_step || behave_count > 50)
        end

        if @debug
          puts "[Ecosystem] npcs #{@npcs.size}, behaving #{@npcs_behaving.size}, behaved this step #{behave_count}, active indexes #{@zone.active_chunk_indexes.size}"
        end

        if @npcs_behaving_idx == @npcs_behaving.size
          @active_chunk_hash = nil
          @npcs_behaving = nil
          @npcs_behaving_idx = nil
        end

      end

    end

    # Quick bench
    if Deepworld::Env.development? || true
      tt = ((Time.now - @@time)*1000).to_i
      @times ||= []
      @times << tt
      @cts ||= []
      @cts << behave_count
      if @times.size == 3000
        p "[Ecosystem] behave_entities: avg time #{@times.mean}ms, median time #{@times[@times.size/2]}ms, max time #{@times.max}ms, avg count #{@cts.mean}, max count #{@cts.max}"
        @times.clear
        @cts.clear
      end
    end

    @last_behave_count = behave_count
  end

  def entities_description
    @npcs.select{ |n| n.mobile? }.map{ |n| "#{n.config.type} @ #{n.position.x}x#{n.position.y}" }.join("\n")
  end

  def servants_of_player(player)
    @npcs.select{ |n| n.servant? && n.owner_id == player.id }
  end

  def blocked?(origin_x, origin_y, offset_x = 0, offset_y = 0, type = 0)
    return true if !@zone.in_bounds?(origin_x + offset_x, origin_y + offset_y)

    blocked = nil
    b = Benchmark.measure do
      blocked = @zone.kernel.blocked?(origin_x, origin_y, offset_x, offset_y, type)
    end
    @zone.increment_benchmark :blocked, b.real
    blocked
  end

  def blocked_to_player?(origin_x, origin_y)
    blocked?(origin_x, origin_y, 0, 0, 1)
  end


  def persist!
    @characters.values.each do |character|
      begin
        character.character.save!
      rescue
        Game.info message: "Character '#{character.name}' couldn't save: #{$!}", backtrace: $!.backtrace
        p "error #{$!}: #{$!.backtrace}"
      end
    end
  end

  def free!
    @npcs.clear
    @players.clear
    @entities.clear
    @characters.clear
  end

  def questers
    @characters.values.select{ |ch| ch.character.try(:job) == "quester" }
  end

  private

  def next_entity_id!
    @entity_lock.synchronize { @next_entity_id += 1 }
  end

  def initialize_entities
    unless %w{no false}.include?(ENV['SPAWN'])
      initialize_block_entities
      unless %w{no false}.include?(ENV['SPAWN_MOBS'])
        initialize_guard_entities
        initialize_characters
        initialize_spawners
      end
    end
  end

  def initialize_block_entities
    block_entity_codes = Game.item_search(/geyser/).values.map{ |e| e.code }

    bench = Benchmark.measure do
      block_entity_codes.each do |e|
        @zone.kernel.block_query(nil, nil, nil, e, nil).each do |ent|
          @zone.spawner.spawn_block_entity Vector2[ent.first, ent.last], Game.item(e).id
        end
      end
    end

    @zone.indexed_meta_blocks[:entity].values.each do |meta|
      if meta.item.entity
        @zone.spawner.spawn_block_entity meta.position, meta.item.id
      end
    end

    Game.add_benchmark :bootstrap_block_entities, bench.real
  end

  def initialize_guard_entities
    # Look through meta blocks and set up any guard objects (enemy protectors)
    @zone.meta_blocks.each_pair do |idx, meta|
      if meta.item.guard && meta.guardians.nil?
        bosses = []

        # Lv5 is big brain
        if meta.item.guard >= 5
          bosses = [:bl, :bs, :bs]

        # Otherwise scale up baddies
        else
          start = meta.item.guard - 1 + (meta.y / 200)
          finish = -(5-meta.item.guard)
          boss_groups = [[:c, :c], [:bs], [:bs, :c], [:bs, :c], [:bs, :c], [:bm], [:bm], [:bm, :bs], [:bm, :bs], [:bmd], [:bmd, :bs], [:bmd, :bs]][start..finish]
          bosses = boss_groups.random + [:c]
          bosses.shift if @zone.difficulty < 3
        end

        boss_codes = bosses.map{ |b| { c: 18, bs: 200, bm: 201, bmd: 202, bl: 203 }[b] }
        meta.data['!'] = boss_codes # Boss data
      end
    end

    # Spawn guards
    guards_spawned = 0
    @zone.meta_blocks.each_pair do |idx, meta|
      if guardians = meta.guardians
        [*guardians].each do |g|
          if guardian = spawn_entity(g, meta.x, meta.y)
            guardian.guard = Vector2[meta.x, meta.y]
            guards_spawned +=1
          end
        end
      end
    end
  end

  def initialize_characters
    if @zone.tutorial?
      spawn_newtons

    else
      Character.where(zone_id: @zone.id).sort(:created_at, -1).all do |characters|

        characters.each do |character|
          spawn_entity character.ilk, character.position[0], character.position[1], character
        end

        # Auto-spawn so that there are at least x characters in a map
        unless Deepworld::Env.test?
          # Spawn newbie Newton
          if @zone.unowned? && characters.none?{ |ch| ch.job == "quester" && ch.name == "Newton" }
            if spawn = @zone.indexed_meta_blocks[:zone_teleporter].values.sort_by{ |mb| mb.x }[1]
              xoffset = [-2, 4, -1, 3].find{ |x| @zone.blocked?(spawn.x + x, spawn.y + 1) && !@zone.blocked?(spawn.x + x, spawn.y) }
              xoffset ||= [-2, 4, -1, 3].find{ |x| @zone.blocked?(spawn.x + x, spawn.y + 1) }
              xoffset ||= 0
              yoffset = xoffset != 0 ? 0 : -15
              if ent = self.spawn_entity('automata/android', spawn.x + xoffset, spawn.y + yoffset)
                ent.name = 'Newton'
                ent.character.update name: 'Newton', job: 'quester', stationary: true
                ent.set_details 'job' => ent.character.job
              end
            end
          end

          # Misc androids
          max_characters = 6
          spawn_characters = max_characters - characters.size
          spawn_characters.times do |ch|
            range = @zone.size.x / spawn_characters
            pos = Vector2[(range * ch + rand(range)).clamp(0, @zone.size.x - 1), 2]
            self.spawn_entity('automata/android', pos.x, pos.y)
          end
        end
      end
    end
  end

  def spawn_newtons
    @zone.meta_blocks.values.select{ |mb| mb.item.code == 199 }.each do |newton|
      if ent = self.spawn_entity('automata/android', newton.position.x, newton.position.y, nil, nil, true)
        ent.name = 'Newton'
        ent.character.update name: 'Newton', job: 'quester', stationary: true
        ent.set_details 'job' => ent.character.job
      end
    end
  end



  # Spawners

  public

  def schedule_spawner(entity_type, position, delay = 5.minutes)
    @spawner_queue_lock.synchronize do
      @spawner_queue << [Time.now + delay, entity_type, position]
    end
  end


  private

  def initialize_spawners
    @zone.meta_blocks.each_pair do |idx, meta|
      if meta.item.spawner
        ent = meta.data['e']
        quantity = meta.data['q']
        (quantity || 1).to_i.times { initialize_spawner ent, meta.position, false }
      end
    end
  end

  def initialize_spawner(entity_type, position, effect = true)
    entity = self.spawn_entity(entity_type, position.x, position.y, nil, effect ? Vector2[0.5, -1] : nil)
    entity.guard = position
    entity.spawned = true
  end

  def process_scheduled_spawners
    @spawner_queue_lock.synchronize do
      # Run any spawns that are ready
      @spawner_queue.reject! do |spawn|
        if Time.now > spawn.first
          initialize_spawner spawn[1], spawn[2]
          true
        else
          false
        end
      end
    end
  end

end
