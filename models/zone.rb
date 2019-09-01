require 'active_support/core_ext/hash'

class Zone < MongoModel
  extend Forwardable

  include Zones::Digging
  include Zones::Exploration
  include Zones::Explosions
  include Zones::Machines
  include Zones::MetaBlocks
  include Zones::Persistence
  include Zones::Protection
  include Zones::Stats
  include Zones::Timers

  include Zones::Banning
  fields [:bannings]

  def_delegators :@ecosystem, :npcs, :questers, :mob_count, :transient_mob_count, :entities, :spawn_entity, :add_entity, :add_client_entity, :remove_entity, :change_entity, :characters, :entities_in_range, :players_in_range, :npcs_in_range, :npcs_at_position, :moved_entity_positions, :all_entity_positions, :find_player, :find_player_by_id, :servants_of_player, :blocked?, :blocked_to_player?

  fields [:name, :data_path, :welcome_message, :last_active_at, :first_online_at, :last_activity_at, :last_missive_check_at, :liquid_step_time, :server_id, :entry_code, :players_count]
  fields [:biome, :difficulty, :pvp, :scenario, :active_duration, :items_mined, :items_placed, :items_crafted, :deaths, :visits, :chunks_explored_count, :explored_percent, :development, :machines_discovered, :machines_configured, :acidity, :depth]
  fields [:active, :shutting_down_at, :private, :premium, :static, :static_type, :locked, :scale, :competition_id, :last_screenshotted_at, :screenshot_token, :force_load, :config, :capacity]
  fields [:version, :migrated_version, :display_name]
  fields [:file_version, :file_versioned_at, :file_version_hist]
  fields [:karma_required, :protection_level, :market, :item_player_limits]
  fields [:geck_discovered] # Deprecated

  fields :size,       Vector2
  fields :chunk_size, Vector2
  fields :members,    Array
  fields :owners,     Array

  # {'command' => [executed_times, last_exectued_at], 'command2' => [executed_times, last_exectued_at]}
  fields :command_history

  attr_reader :kernel, :freed, :ecosystem, :static_zone, :boot_time, :last_saved_at, :minigames, :competition
  attr_reader :chunk_width, :chunk_height, :chunk_count, :chunks_explored, :liquid_reserves, :surface, :surface_max, :time_gates, :time_ticks
  attr_reader :recent_chats

  attr_accessor :meta_blocks, :indexed_meta_blocks

  # Status
  attr_accessor :daytime, :temperature, :wind, :cloud_cover, :precipitation
  attr_accessor :light, :liquid, :steam, :weather, :invasion, :daytime_cycle, :growth, :dungeon_master, :liquid_enabled, :spawner, :seismic, :cleaner, :frozen_until
  attr_accessor :suppress_flight, :suppress_guns, :suppress_mining, :suppress_turrets, :suppress_spawners, :suppress_chat

  # Message information queues
  attr_accessor :block_update_queue

  def after_initialize
    if @after_initialized
      Alert.create :zone_initialized_twice!, :critical, "Zone #{name}(#{id}) initialized twice"
    end
    @after_initialized = true

    @config             ||= {}
    @premium = true if @premium.nil?
    @biome              ||= 'plain'
    @biome              = @biome.to_s
    @market             ||= false

    @difficulty         ||= 3
    @file_write_lock    = Mutex.new

    @block_update_queue = {}
    @dig_queue          = []
    @dig_queue_lock     = Mutex.new
    @block_timer_queue  = {}
    @block_timer_lock   = Mutex.new
    @last_block_updates = {}
    @block_update_lock  = Mutex.new
    @time_gates         = {}
    @time_ticks         = {}
    @step_mod           = 0
    @kernel             = nil
    @liquid             = nil
    @steam              = nil
    @cache              = Cache.new
    @achievements       = Game.config.achievements.select{ |ach, cfg| cfg.interval }.values.map{ |cfg| "Achievements::#{cfg['type']}".constantize.new }
    @minigames          = []
    @owners             ||= []
    @members            ||= []
    @command_history    ||= {}
    @bannings           ||= {}
    @recent_chats       ||= []

    # =============================
    # Timing
    # =============================
    @last_step          ||= Time.now
    @boot_time          ||= Time.now
    @last_activity_at   ||= Time.now
    @last_missive_check_at ||= Time.now
    @last_active_at     ||= Time.now
    @time_since_last_run  = Time.now - @last_active_at
    @first_online_at    ||= Time.now

    # =============================
    # Flags
    # =============================
    @paused             = true
    @liquid_enabled     = true if @liquid_enabled.nil?
    @shutting_down_at   ||= nil
    @last_saved_at      ||= Time.now
    @spawn              = %w{no false}.include?(ENV['SPAWN']) || %w{no false}.include?(ENV['SPAWN_MOBS']) ? false : true

    # =============================
    # Statistics
    # =============================
    @active_duration     ||= 0
    @items_mined         ||= 0
    @items_placed        ||= 0
    @items_crafted       ||= 0
    @deaths              ||= 0
    @visits              ||= 0
    @machines_discovered ||= { purifier: @geck_discovered }
    @machines_configured ||= {}
    @machines_discovered = @machines_discovered.with_indifferent_access
    @benchmarks     = {}
    @frozen_until = Time.now - 1.second

    if ENV['VANILLA']
      ENV['DAY'] = '999999999'
      ENV['LIQUID'] = 'no'
      ENV['WEATHER'] = 'no'
      @active_duration = 999999999 * 0.5
    end

    if ['test','development'].include?(Deepworld::Env.environment)
      load_local!
      sleep ENV['ZONE_SLEEP'].to_i if ENV['ZONE_SLEEP']
    else
      load_s3!
    end

    @weather        = Dynamics::Weather.new(self) unless @biome == "space" || %w{no false}.include?(ENV['WEATHER'].try(:downcase))
    @weather.rain   = Dynamics::Weather::Rain.random_rain(:wet) if @weather && ENV['RAIN']
    @spawner        = Npcs::Spawner.new(self)
    @seismic        = Dynamics::Seismic.new(self) unless @biome == "space" || competition?
    @cleaner        = Dynamics::Cleaner.new(self) unless @biome == "space" || competition?
    @dungeon_master = Dynamics::DungeonMaster.new(self)
    @invasion       = Dynamics::Invasion.new(self)
    @happenings     = Dynamics::Happenings.new(self) unless tutorial?

    # Status
    @daytime_cycle = ENV['DAY'] ? ENV['DAY'].to_f : 20.0 * 60.0
    @daytime = ENV['DAY'] ? 0.5 : ((@active_duration + @daytime_cycle*0.5) % @daytime_cycle) / @daytime_cycle
    @temperature = (0.7..0.9).random
    @wind = (0..0.4).random
    @cloud_cover = (0.1..0.4).random
    @precipitation = 0
    @acidity ||= 1.0

    @item_player_limits ||= {}
    @item_player_limits.dup.each_pair do |i, q|
      @item_player_limits[Game.item_code(i)] = q
    end

    initialize_competition

    # Set up staticness
    @static_zone  = StaticZone.new(self) if static

    @ecosystem    = Ecosystem.new(self)

    migrate!
    simulate! @time_since_last_run
    clear_portals
    own_portals

    @biome_module = "Biomes::#{@biome.capitalize}".constantize.new(self) rescue nil
    @biome_module.load if @biome_module

    @scenario_module = "Scenarios::#{@scenario.camelize}".constantize.new(self) rescue nil
    @scenario_module.load if @scenario_module

    @responders = {
      kill: [Zones::KillResponder.new(self)]
    }
  end

  # For testing ocean stats
  def liquify_air!(starting_y = 0)
    (0..@size.x-1).each do |x|
      (starting_y..@size.y-1).each do |y|
        update_block(nil, x, y, LIQUID, 100, 5) if peek(x, y, LIQUID)[0] == 0
      end
    end
  end

  def name_to_display
    if self.display_name.present?
      self.display_name
    elsif self.static?
      @static_zone.name
    elsif scenario && scenario =~ /Tutorial/
      "Tutorial"
    elsif beginner?
      "H.M.S. Challenge"
    else
      @name
    end
  end

  def to_s
    "#<Zone:#{self.id} #{self.name}>"
  end

  def queue_message(message, chunk_index = nil)
    Game.queue_message self.id, message, chunk_index
  end

  def validate_command(command)
    @scenario_module.validate_command command if @scenario_module
  end

  # Does a dumb non-collision detected attempt, and return nil if collision
  def recode!(&block)
    code = "z" + Deepworld::Token.generate(6)

    Zone.where({entry_code: code}).fields(:_id).callbacks(false).first do |z|
      if z.nil?
        self.update(entry_code: code) do
          yield code if block_given?
        end
      else
        yield nil if block_given?
      end
    end
  end

  def rename!(new_name)
    # Change the welcome message
    welcome = self.welcome_message.gsub(/#{self.name}/, new_name)
    self.update({welcome_message: welcome, name: new_name, name_downcase: new_name.downcase}) do
      yield new_name if block_given?
    end
  end

  def reconnect_all!(msg = nil)
    players.each { |p| p.connection.kick(msg, true) }
  end

  def owned?
    @owners.present?
  end

  def unowned?
    @owners.blank?
  end

  def can_trade?
    @market || self.private
  end

  def default_capacity
    50
  end

  def initialize_competition
    if competition_id
      Competition.find_by_id(competition_id) do |comp|
        if comp
          @competition = comp
          @competition.setup_zone self
        end
      end
    end
  end

  def competition?
    @competition_id.present?
  end

  def chat(player, text, recipient)
    player_event player, :chat, text
    @recent_chats.shift if @recent_chats.size > 40
    @recent_chats << [player.id, player.name, text, recipient.try(:id), Time.now]
  end

  def player_event(player, event, data)
    @scenario_module.player_event player, event, data if @scenario_module
    @minigames.each do |m|
      m.player_event player, event, data
    end

    if responders = @responders[event]
      responders.each do |r|
        r.player_event player, data
      end
    end

    player.quest_event event, data
  end



  def end_minigames
    @minigames.dup.each{ |m| m.finish! }
  end



  # ===== Main zone game loop ===== #

  def step!(force = false)
    return if @freed

    raise "Meta blocks not indexed!" if @indexed_meta_blocks.nil?

    @step_mod += 1
    @step_mod = 0 if @step_mod % 32 == 0

    return if @paused and !force

    zone_step_benchmark = Benchmark.measure do

      begin
        now = Time.now
        delta_time = now - @last_step
        @active_duration += delta_time

        @daytime += delta_time * (1.0 / @daytime_cycle)
        @daytime -= 1.0 if @daytime >= 1.0

        @kernel.step! active_chunk_indexes.keys

        # Every 1/4 second
        if @step_mod % 2 == 0
          EM.next_tick { liquid_step! }
          EM.next_tick { process_block_timers }
        else
          EM.next_tick { send_block_changes }
          EM.next_tick { step_players }
        end

        # Every second
        EM.next_tick { steam_step! } if @step_mod % 8 == 0
        EM.next_tick { process_achievements } if @step_mod % 8 == 1
        EM.next_tick { process_timers } if @step_mod % 8 == 2
        EM.next_tick { process_field_damage } if @step_mod % 8 == 3

        # Every 4 seconds
        EM.next_tick { process_purifier 4.0 } if @step_mod % 32 == 0
        EM.next_tick { send_zone_status } if @step_mod % 32 == 8
        EM.next_tick { get_missives } if @step_mod % 32 == 16

        EM.next_tick do
           @weather.step! delta_time if @weather && !Deepworld::Env.test?
           @seismic.step! delta_time if @seismic
           @cleaner.step! delta_time if @cleaner
           @happenings.step! delta_time if @happenings
           @ecosystem.step! if @ecosystem
           @spawner.spawn_entities if @spawn && @spawner
           step_minigames delta_time
        end

        EM.next_tick do
          @biome_module.step(delta_time) if @biome_module
          @scenario_module.step(delta_time) if @scenario_module
          tick_benchmarks
        end

        @time_ticks.keys.each do |k|
          @time_ticks[k] -= delta_time
          @time_ticks[k] = 0 if @time_ticks[k] < 0
        end

        @last_step = now
      rescue
        self.info({ message: "Zone step exception: #{$!}", backtrace: $!.backtrace.first(7) }, true)
        raise if Deepworld::Env.test?
      end
    end

    Game.add_benchmark :zone_step, zone_step_benchmark.real
  end

  def behave!(delta_time)
    EM.next_tick do
      @ecosystem.behave_entities delta_time if @ecosystem
    end
  end

  # Simulate world for a bit
  def simulate!(time = 0)
    return unless time > 0

    time = [time, 3.days].min # Max of 3 days of simulation
    Game.info "Simulating zone #{name} for #{(time/60).to_i} minutes"

    # Purification
    process_purifier(time)

    time = [time, 1.day].min # Less simulation for growth / seismic

    # Growth
    self.growth_step!(time / 20.minutes) if acidity < 0.05

    # Seismic
    self.seismic.simulate! time if self.seismic
  end

  def clear_portals
    portals = @indexed_meta_blocks[:zone_teleporter].values + @indexed_meta_blocks[:teleporter].values

    portals.each do |meta|
      size    = meta.item.block_size.map{|v| v.clamp(1,3)}
      right   = [meta.x + (size[0] - 1), self.size.x - 1].min
      bottom  = [meta.y - (size[1] - 1), self.size.y - 1].min

      (meta.x..right).each do |x|
        (bottom..meta.y).each do |y|
          next if x < 0 || y < 0
          update_block nil, x, y, FRONT, 0 unless x == meta.x && y == meta.y
          update_block nil, x, y, LIQUID, 0, 0
        end
      end
    end
  end

  # Attach world owner to world teleporters if necessary
  def own_portals
    if owner = owners.first
      @indexed_meta_blocks[:zone_teleporter].values.each do |meta|
        meta.player_id = owner.to_s
      end
    end
  end

  def teleporters_in_range(origin, range)
    ((@indexed_meta_blocks[:teleporter].values || []) + (@indexed_meta_blocks[:zone_teleporter].values || [])).select do |t|
      Math.within_range?(origin, t.position, range)
    end
  end

  def spawns_in_range(origin, range)
    (@indexed_meta_blocks[:zone_teleporter].values || []).select do |t|
      Math.within_range?(origin, t.position, range)
    end
  end

  def meta_blocks_in_range(origin, range, _index)
    (@indexed_meta_blocks[_index].values || []).select do |t|
      Math.within_range?(origin, t.position, range)
    end
  end

  def process_achievements
    return unless @ecosystem

    Game.add_benchmark :process_achievements do
      players.each do |player|
        @achievements.each do |ach|
          ach.check player
        end
      end
    end
  end

  def process_timers
    return unless @ecosystem

    Game.add_benchmark :process_timers do
      players.each do |player|
        player.process_timers
      end
    end
  end

  def process_field_damage
    Game.add_benchmark :process_field_damage do
      field_damage_blocks = @indexed_meta_blocks[:field_damage].values

      players.each do |player|
        player.damage_if_in_field_range! field_damage_blocks
      end
    end
  end

  def tick_benchmarks
    @benchmarks.each_pair { |key, time| Game.add_benchmark key, time }
    @benchmarks.clear
  end

  def increment_benchmark(key, time)
    @benchmarks[key] = (@benchmarks[key] || 0) + time
  end

  def rain_complete
    self.growth_step! if purified? || @biome == 'hell'
  end

  def purified?
    acidity < 0.05
  end

  def growth_step!(rain_cycles=1)
    return if @growth_processing

    @growth_processing = true
    process_growth = Proc.new do
      growth_benchmark = Benchmark.measure { @growth.step!(rain_cycles) }
      growth_benchmark.real
    end

    growth_complete = Proc.new do |time|
      @growth_processing = false
    end

    # Call growth step directly if test, otherwise defer it
    if Deepworld::Env.environment == 'test'
      process_growth.call
    else
      EventMachine.defer(process_growth, growth_complete)
    end
  end

  def liquid_step!
    return unless (@liquid && Game.liquid_enabled and @liquid_enabled && !@liquid_processing)

    @liquid_processing = true
    process_liquid = Proc.new do
      liquid_benchmark = Benchmark.measure { @liquid.step! }
      liquid_benchmark.real
    end

    liquid_complete = Proc.new do |time|
      Game.add_benchmark :liquid_step, time
      @liquid_processing = false
    end

    # Call liquid step directly if test, otherwise defer it
    if Deepworld::Env.environment == 'test'
      process_liquid.call
    else
      EventMachine.defer(process_liquid, liquid_complete)
    end
  end

  def steam_step!
    return unless (@steam && Game.steam_enabled && !@steam_processing)

    @steam_processing = true
    process_steam = Proc.new do
      collectors = @indexed_meta_blocks[:collector].values.map(&:position_array)
      machines = @indexed_meta_blocks[:steam].values.map(&:position_array)
      steam_benchmark = Benchmark.measure { @steam.step!(collectors, machines, always_activate_collectors?) }
      steam_benchmark.real
    end

    steam_complete = Proc.new do |time|
      Game.add_benchmark :steam_step, time
      @steam_processing = false
    end

    # Call steam step directly if test, otherwise defer it
    if Deepworld::Env.environment == 'test'
      process_steam.call
    else
      EventMachine.defer(process_steam, steam_complete)
    end
  end

  def always_activate_collectors?
    competition?
  end

  def players
    @ecosystem ? @ecosystem.players : []
  end

  def entities
    @ecosystem ? @ecosystem.entities : []
  end

  def add_player(player)
    @ecosystem.add_entity(player)
    @visits += 1
    update players_count: @ecosystem.players.count

    # Send entry messages to peers
    player.send_peers_status_update
    player.queue_peer_messages EntityPositionMessage.new([player.position_array])

    player.send_peers_pvp_team_message

    true
  end

  def remove_player(player)
    # Send status to other players
    player.queue_peer_messages EntityStatusMessage.new(player.status(Entity::STATUS_EXITED))

    # Remove from ecosystem
    @ecosystem.remove_entity(player) if @ecosystem

    update players_count: players.count
  end

  def step_players
    Game.add_benchmark :step_players do
      players.each{ |p| p.step }
    end
  end

  def send_entity_positions_to_all
    players.each do |player|
      player.send_entity_positions
    end
  end

  # Send zone status (weather, etc.) to all players
  def send_zone_status
    players.each do |player|
      player.queue_message ZoneStatusMessage.new(status_info(player))
    end
  end

  def send_block_changes
    Game.add_benchmark :send_block_changes do
      process_dig_queue Time.now

      updates = nil
      @block_update_lock.synchronize do
        updates = @block_update_queue.dup
        @block_update_queue.clear
      end

      # Discard changes that were the exact same last frame
      updates.reject! { |k, v| v == @last_block_updates[k] }
      @last_block_updates = updates.dup

      block_changes = {}

      updates.each do |u|
        idx = chunk_index(u.first[0], u.first[1])

        block_changes[idx] ||= []
        block_changes[idx] << u.flatten
      end

      block_changes.each do |idx, msg|
        queue_message BlockChangeMessage.new(msg), idx
      end
    end
  end

  # Pause the zone game loop
  def pause
    @paused = true
  end

  # Resume the zone game loop
  def play
    @paused = false
  end

  # Positioning

  def next_spawn_point(player)
    # Attempt to find a zone teleport and place there
    [934, 891, 890].each do |spawn_item|
      item = Game.item(spawn_item)
      item_width = item.block_size[0]

      spawns = []
      @meta_blocks.each_pair do |idx, meta|
        if meta.item.code == spawn_item
          spawns << meta
        end
      end

      if spawns.size > 0
        spawns.sort_by!(&:x)
        spawn = player.quests.size < 5 && spawns.size > 1 ? spawns[1] : spawns.random # Newbs always at middle spawn
        x_offset = (item_width-1)*0.5
        return Vector2.new(spawn.x + x_offset, spawn.y)
      end
    end

    # If no zone spawn points, put em in the air
    Vector2[size.x / 2, 2]
  end

  def random_point
    Vector2.new(rand(size.x), rand(size.y))
  end

  def tutorial?
    self.static? && self.static_type == 'tutorial'
  end

  def beginner?
    scenario && (scenario == 'Beginner' || scenario =~ /Tutorial/)
  end

  def static?
    !!self.static
  end

  def show_hints?
    !tutorial? && !beginner? && scenario != 'HomeWorld'
  end

  def status!(type, val)
    case type
    when :suppress_flight
      @suppress_flight = val
      queue_message ZoneStatusMessage.new('suppress_flight' => val)
    when :suppress_guns
      @suppress_guns = val
      queue_message ZoneStatusMessage.new('suppress_guns' => val)
    when :suppress_mining
      @suppress_mining = val
      queue_message ZoneStatusMessage.new('suppress_mining' => val)
    end
  end

  def status_info(player = nil)
    info = [@daytime, @temperature, @wind, @cloud_cover, @precipitation, @acidity].map{ |i| (i * 10000).to_i }
    player.try(:client_version?, '2.1.0') ? { 'w' => info } : info
  end

  def position_description(position, markup = true)
    x = (position.x - (@size.x * 0.5)).to_i
    y = (position.y - 200).to_i

    east_west = x > 0 ? "east" : (x < 0 ? "west" : "central")
    up_down = markup ? " #{y.abs}m#{y > 0 ? ":down:" : ":up:"}" : ", #{y.abs}m #{y > 0 ? "down" : "up"}"
    "#{x.abs} #{east_west}#{up_down}"
  end

  def normalized_position(position)
    if position && position.x.abs < @size.x/2 && (-199..@size.y-201).include?(position.y)
      Vector2[position.x + @size.x/2, position.y+200]
    else
      nil
    end
  end

  def get_missives
    if !tutorial? && scenario != 'Beginner'
      Missive.query_for_players players, { '$gt' => last_missive_check_at }, 1, 50
      @last_missive_check_at = Time.now
    end
  end




  # ===== Blocks / Chunks ===== #

  def block_index(x, y)
    y * @size.x + x
  end

  def block_position(idx)
    Vector2[idx % @size.x, idx / @size.x]
  end

  # Gives you the index of the chunk at the provided zone coordinates
  def chunk_index(x, y)
    return nil unless in_bounds?(x, y)
    chunk_pos = chunk_position(x, y)
    chunk_pos.y * @chunk_width + chunk_pos.x
  end

  def chunk_at_position(pos)
    get_chunk(chunk_index(pos.x, pos.y))
  end

  def chunks_in_rect(rect)
    chunks = []
    (rect.left/@chunk_size.x..rect.right/@chunk_size.x).each do |ch_x|
      (rect.top/@chunk_size.y..rect.bottom/@chunk_size.y).each do |ch_y|
        pos = Vector2[ch_x*@chunk_size.x, ch_y*@chunk_size.y]
        if in_bounds?(pos.x, pos.y)
          chunks << chunk_at_position(pos)
        end
      end
    end
    chunks
  end

  # Chunk vector for block
  def chunk_position(x, y)
    Vector2.new (x / @chunk_size.x).floor, (y / @chunk_size.y).floor
  end

  def client_config(player = nil, allow_for_tests = false)
    return {} if (Deepworld::Env.test? && !allow_for_tests)

    cfg = {
      'id' => @id.to_s,
      'biome' => @biome,
      'size' => [@size.x, @size.y],
      'chunk_size' => [@chunk_size.x, @chunk_size.y],
      'time' => run_time.to_f,
      'surface' => @surface,
      'chunks_explored' => @chunks_explored,
      'chunks_explored_count' => @chunks_explored_count,
      'seed' => @id.to_s[0..7].hex
    }
    cfg['static'] = true if @static
    cfg['owner'] = true if player && self.owners.include?(player.id)
    cfg['member'] = true if player && (cfg['owner'] || self.members.include?(player.id))
    cfg['pvp'] = true if @pvp
    cfg['bookmarked'] = true if player.bookmarked_zones.include?(self.id)
    cfg['name'] = self.name_to_display + (Deepworld::Env.production? ? '' : " [#{Deepworld::Env.development? ? 'Dev' : Deepworld::Env.environment.capitalize}]")
    cfg['suppress_flight'] = true if @suppress_flight
    cfg['suppress_guns'] = true if @suppress_guns
    cfg['suppress_mining'] = true if @suppress_mining
    if @depth
      if player.v3?
        cfg['depth'] = {
          "ground/earth" => [
            [@depth[3], "ground/earth-deepest"],
            [@depth[2], "ground/earth-deeper"],
            [@depth[1], "ground/earth-deep"]
          ]
        }
      else
        key = biome == "plain" ? "temperate" : biome
        cfg['depth'] = {
          "#{key}/earth-front" => [
            [@depth[1], "#{key}/earth-front-deep"],
            [@depth[2], "#{key}/earth-front-deeper"],
            [@depth[3], "#{key}/earth-front-deepest"]
          ]
        }
      end
    end

    if player.client_version?('3.1.5')
      cfg['private'] = @private.nil? ? false : @private
      cfg['protected'] = @protection_level.to_i > 0
      cfg['protected_player'] = protected_against?(player)
      cfg['protected_reason'] = 'This world is reserved for high-level players' if (1..9).include?(@protection_level)
    else
      if protected_against?(player)
        cfg['protected'] = true
        cfg['protected_reason'] = 'This world is reserved for high-level players' if (1..9).include?(@protection_level)
      end
    end

    cfg
  end

  def update_player_configuration(player, cfg)
    @scenario_module.update_player_configuration player, cfg if @scenario_module
  end

  def in_bounds?(x, y)
    x >= 0 && x < size.x && y >= 0 && y < size.y
  end

  def get_chunk(chunk_index)
    return nil unless chunk_index and (0..@chunk_count-1).include?(chunk_index)
    Chunk.new(self, chunk_index)
  end

  def peek(x, y, layer)
    @kernel.block_peek(x, y, layer)
  end

  # Returns array:
  # [base.item, back.item, back.mod, front.item, front.mod, liquid.item, liquid.mod]
  def all_peek(x, y)
    @kernel.all_peek(x, y)
  end

  def block_owner(x, y, layer)
    @kernel.block_owner(x, y, layer)
  end

  def block_natural?(x, y, layer = FRONT)
    block_owner(x, y, layer) == 0
  end

  def chunk_data(indexes)
    @kernel.chunk_data(indexes)
  end

  def raycast(origin, destination, liquid = false, items = false)
    result = nil
    b = Benchmark.measure do
      begin
        result = @kernel.raycast(origin.x, origin.y, destination.x, destination.y, false, liquid, false, false, items)
      rescue
        Game.info({error: "zone#raycast called with origin: #{origin.x}, #{origin.y} destination: #{destination.x}, #{destination.y}", fid: self.id, exception: Kernel.caller.first}, true)
        nil
      end
    end
    increment_benchmark :raycast, b.real
    result
  end

  def raynext(origin, destination, liquid = false)
    result = nil
    b = Benchmark.measure do
      begin
        path = @kernel.raycast(origin.x, origin.y, destination.x, destination.y, true, liquid, false, true, false)
        result = path[1] if path # The first position is the origin
      rescue
        Game.info({error: "zone#raycast called with origin: #{origin.x}, #{origin.y} destination: #{destination.x}, #{destination.y}", zone_id: self.id, exception: Kernel.caller.first}, true)
        nil
      end
    end
    increment_benchmark :raynext, b.real
    result
  end

  def raypath(origin, destination, liquid = false, all = false, items = false)
    result = nil
    b = Benchmark.measure do
      begin
        result = @kernel.raycast(origin.x, origin.y, destination.x, destination.y, true, liquid, all, false, items)
      rescue
        Game.info({error: "zone#raycast called with origin: #{origin.x}, #{origin.y} destination: #{destination.x}, #{destination.y}", zone_id: self.id, exception: Kernel.caller.first}, true)
        nil
      end
    end
    increment_benchmark :raypath, b.real
    result
  end

  def update_block_owner(x, y, layer, player)
    item, mod = peek(x, y, layer)

    @kernel.block_update(x, y, layer, item, mod, player.digest)
    if meta = get_meta_block(x, y)
      meta.player_id = player.id.to_s
    end

    queue_block_update(nil, x, y, layer, item, mod)
    queue_message meta_blocks_message({ block_index(x, y) => meta }) if meta
  end

  def update_block(entity_id, x, y, layer, item = nil, mod = nil, player_or_digest = nil, meta = nil)
    return unless item or mod

    item_config = item ? Game.item(item) : nil

    # Deal with meta information if necessary
    unless meta == :skip
      if item_config && layer == FRONT
        if item_config.meta
          player = player_or_digest.respond_to?(:player?) ? player_or_digest : @ecosystem.find(entity_id)
          set_meta_block x, y, item_config, player, meta
        elsif meta = get_meta_block(x, y)
          meta.clear!
          set_meta_block x, y, nil
        end
      end
    end

    digest = player_or_digest.respond_to?(:digest) ? player_or_digest.digest : player_or_digest
    @kernel.block_update(x, y, layer, item || peek(x, y, layer)[0], mod, digest)

    if layer == FRONT
      # Update light info if front
      light.recalculate x if light.light_at(x, y)

      # Remove any block timer at this position
      remove_block_timer Vector2[x, y]
    end

    # Queue update to be sent out
    queue_block_update(entity_id, x, y, layer, item, mod)
  end

  def queue_block_update(entity_id, x, y, layer, item, mod)
    @block_update_lock.synchronize do
      @block_update_queue[[x, y, layer]] = [entity_id, item, mod]
    end
  end

  def queue_light_update(x, y)
    queue_message LightMessage.new([[x, 0, 0, [y].flatten]])
  end

  def active_chunk_indexes
    @cache.get(:active_chunk_indexes, 0.25) do
      @active_chunk_hash = nil
      players.map(&:active_indexes).flatten.inject({}){ |hash, i| hash[i]=true; hash }
    end
  end

  # Chunks that are directly around players
  def immediate_chunk_indexes
    @cache.get(:immediate_chunk_indexes, 0.25) do
      players.select{|p| !p.position.nil? }.map do |p|
        [
          p.position + Vector2.new(-@chunk_size.x, -@chunk_size.y),
          p.position + Vector2.new(0, -@chunk_size.y),
          p.position + Vector2.new(@chunk_size.x, -@chunk_size.y),
          p.position + Vector2.new(-@chunk_size.x, 0),
          p.position,
          p.position + Vector2.new(@chunk_size.x, 0),
          p.position + Vector2.new(-@chunk_size.x, @chunk_size.y),
          p.position + Vector2.new(0, @chunk_size.y),
          p.position + Vector2.new(@chunk_size.x, @chunk_size.y)
        ].map{ |pos| self.chunk_index pos.x.to_i, pos.y.to_i }
      end.flatten.compact.inject({}){ |hash, i| hash[i]=true; hash }
    end
  end

  # Chunks that players are positioned in
  def occupied_chunk_indexes
    players.map{ |p| self.chunk_index(p.position.x.to_i, p.position.y.to_i) }.uniq
  end

  def position_active?(position)
    idx = chunk_index(position.x.to_i, position.y.to_i)
    active_chunk_indexes.include?(idx)
  end

  def position_immediate?(position)
    idx = chunk_index(position.x.to_i, position.y.to_i)
    immediate_chunk_indexes.include?(idx)
  end

  def place_prefab(x, y, prefab, player = nil)
    prefab.blocks.each_with_index do |block, index|
      bx = x + (index % prefab.size[0])
      by = y - prefab.size[1] + (index / prefab.size[0]) + 1

      update_block nil, bx, by, BACK, block[1], block[2], player
      update_block nil, bx, by, FRONT, block[3], block[4], player
      update_block nil, bx, by, LIQUID, block[5], block[6], player
    end
  end

  def run_time
    Time.now - @boot_time
  end

  def report!
    @last_active_at = Time.now

    self.update({
      last_active_at: @last_active_at,
      first_online_at: @first_online_at,
      players_count: players.count,
      entities_count: entities.count,
      boot_time: @boot_time,
      active_duration: @active_duration,
      items_mined: @items_mined,
      items_placed: @items_placed,
      items_crafted: @items_crafted,
      deaths: @deaths,
      visits: @visits
    })
  end

  # Ensure we're still on the right server
  def check!
    Zone.find_one(@id, callbacks: false) do |zone|
      if zone.server_id != Game.document_id
        players_count = players.size
        players_description = players.map{ |p| "#{p.id}" }.join(', ')
        players.each { |p| p.connection.kick('Changing servers', true) }
        alert_deets = { server_id: Game.document_id, server_ip: Game.ip, server_port: Game.port, zone_id: @id }

        begin
          server_msg = "Zone #{zone.name} (id #{@id}) duplicatively loaded at #{Time.now} on server #{Game.document_name} (id #{Game.document_id}), should be on #{zone.server_id || 'none?'}."
          Alert.create :zone_duplication, :critical, "#{server_msg} Players (#{players_count}): #{players_description}"
        rescue
          Alert.create :zone_duplication, :critical, "Zone #{zone.name} duplicatively loaded, error in alert: #{$!.message}"
        end

        # Remove players and kill self
        Game.zones.delete self.id
        self.free!
      end
    end
  end

  def shutdown!(should_persist = true, should_reconnect = false, &block)
    if @shutting_down_at
      Game.info error: "Zone.shutdown! called again", zone_id: self.id, exception: Kernel.caller.first, backtrace: Kernel.caller.first(8)
      if block_given?
        yield self
      else
        return
      end
    end

    process_block_timers true
    end_minigames

    self.update({last_active_at: Time.now, shutting_down_at: Time.now, server_id: nil, players_count: 0}) do
      Game.info message: "Zone shutting_down_at set. '#{self.name}'", zone: id.to_s

      # Kick the players
      players.dup.each { |player| player.kick(nil, should_reconnect) }

      # Persist the file
      begin
        self.persist! if should_persist
      rescue Exception => e
        Game.info message: "Zone save failure '#{self.name}' file #{self.data_path}: #{e.message}", zone: id.to_s, backtrace: $!.backtrace
      end

      # Flag as shut down
      self.update({shutting_down_at: nil}) do
        Game.info message: "Zone shutting_down_at nild. '#{self.name}'", zone: id.to_s

        Game.zones.delete self.id

        yield self if block_given?
      end
    end
  end

  def free!
    @freed      = true

    @kernel.free! if @kernel
    @liquid.free! if @liquid
    @steam.free!  if @steam

    @achievements.clear
    @meta_blocks.clear
    @weather      = nil
    @spawner      = nil
    @seismic      = nil
    @cleaner      = nil

    @ecosystem.free!

    GC.start
  end

  def info(data, force = false)
    data = { message: data } if data.is_a?(String)
    Game.info data.merge(zone_id: self.id), force
  end

  def spawn_item_entities(position, item)
    qty = item.spawn_entity_quantity ? (item.spawn_entity_quantity[0]..item.spawn_entity_quantity[1]).random : 1
    qty.to_i.times do
      entity_type = item.spawn_entity.random_by_frequency
      spawn_entity entity_type, position.x, position.y
    end
  end

  # Returns a destination for a ray that's bounded by the zone
  def ray_destination(origin, ray, distance)
    distance.times.each do |d|
      destination = (origin + (ray * (distance - d))).fixed
      return destination if in_bounds?(destination.x, destination.y)
    end
    origin
  end

  # Request player to submit screenshot
  def check_screenshot(player)
    if !@last_screenshotted_at || Time.now > @last_screenshotted_at + 1.day || Deepworld::Env.development?
      update screenshot_token: SecureRandom::base64, last_screenshotted_at: Time.now do
        player.queue_message UploadMessage.new('zone', screenshot_token, "http://#{Deepworld::Settings.codex}/worlds/#{id}/screenshot")
      end
    end
  end


  # ===== Minigames =====  #

  def start_minigame(type, position = nil, player = nil, setup_values = nil)
    if minigame_class = ("Minigames::#{type.to_s.camelize}".constantize rescue nil)
      minigame = minigame_class.new(self, position, player, setup_values)
      minigame.start!
      minigame
    end
  end

  def step_minigames(delta)
    @minigames.select! do |minigame|
      minigame.step! delta
      minigame.active?
    end
  end

  def minigame_at_position(position)
    @minigames.find{ |m| m.origin.x == position.x && m.origin.y == position.y }
  end

  def rejoin_minigame(player)
    if minigame = @minigames.find{ |m| m.participating?(player) }
      player.join_minigame minigame
    end
  end




  # ===== Membership ===== #

  def is_owner?(player_id)
    player_id = player_id.id if player_id.is_a? Player

    [self.owners].flatten.compact.include? player_id
  end

  def is_member?(player_id)
    player_id = player_id.id if player_id.is_a? Player

    [self.members].flatten.compact.include? player_id
  end

  def can_play?(player_id)
    player_id = player_id.id if player_id.is_a? Player

    if self.active
      if self.private
        ([self.owners] + [self.members]).flatten.compact.include? player_id
      else
        true
      end
    else
      false
    end
  end

  def accessibility_for(player)
    # Determine accessibility
    if player.owned_zones.include? self.id
      accessibility = 'a'
    elsif self.premium
      accessibility = 'p'
    else
      accessibility = 'a'
    end
  end

  def add_owner(player)
    # Make this player the owner and add to owned_zones
    player.update({'$addToSet' => { owned_zones: self.id }}, false) do
      self.update({'$addToSet' => { owners: player.id }}, false) do
        yield if block_given?
      end
    end
  end

  def add_member(player)
    # Add the player to members and add to member zones
    player.update({'$addToSet' => { member_zones: self.id }}, false) do
      self.update({'$addToSet' => { members: player.id }}, false) do
        yield if block_given?
      end
    end
  end

  def remove_member(player)
    player_updates = {member_zones: (player.member_zones || []) - [self.id], visited_zones: (player.visited_zones || []) - [self.id]}
    player_updates.merge!({zone_id: nil, spawn_point: nil, position: nil}) if player.zone_id == self.id

    # Remove the player from zone members
    self.update({'$pull' => { members: player.id }}, false) do

      # Save and kick if ingame
      if ingame_player = find_player_by_id(player.id)
        ingame_player.save!(player_updates) do
          ingame_player.send_to(nil)
          yield if block_given?
        end

      # Or just update member_zones and remove from this zone
      else
        player.update(player_updates) do
          yield if block_given?
        end
      end
    end
  end

  def show_in_recent?
    @scenario_module.nil? || @scenario_module.show_in_recent?
  end

  ###################
  ## Administrative
  ###################
  def purifier_locations
    meta_block_locations(Game.item_code('mechanical/geck-tub'), Game.item_code('mechanical/geck-cog-small'))
  end

  def meta_block_locations(from_code, to_code = nil)
    to_code = from_code unless to_code

    meta_blocks.values.select {|m| m.item.code >= from_code && m.item.code <= to_code}.map{|i| [i.item.code, i.x, i.y]}
  end

  def find_items(item_code, layer = FRONT)
    query = [nil, nil, nil, nil]

    case layer
    when BASE
      query[0] = item_code
    when BACK
      query[1] = item_code
    when FRONT
      query[2] = item_code
    when LIQUID
      query[3] = item_code
    end

    result = []

    (0..@chunk_count-1).map do |chunk|
      result << @kernel.block_query(chunk, *query)
    end

    result.compact.flatten(1)
  end

  private

  def migrate!
    migrator = Migrator.new
    migrator.migrate(self)
  end

end
