require 'benchmark'
require 'syslog'
require 'fileutils'
require 'yajl'
require 'pry-remote'

class GameServer
  extend Forwardable
  def_delegators :@config, :item, :items, :item_exists?, :item_search, :item_code, :whole_items, :shelter_items, :items_by_category

  attr_accessor :zones, :connections, :config, :liquid_enabled, :steam_enabled, :version, :achievements, :loot, :exit_code, :maintenance, :pid, :players_online
  attr_accessor :kernel_config, :analyzed_benchmarks, :schedule
  attr_reader :ip, :port

  # For test purposes
  attr_accessor :latest_connection

  module LoadStatus
    SUCCESS = 0
    STUCK   = 1
    REROUTE = 2
    FAILURE = 3
    FATAL   = 4
  end

  def initialize
    Thread.abort_on_exception = true

    @zones                      = ThreadSafe::Hash.new # Zones keyed by zone id
    @alerts_sent                = ThreadSafe::Hash.new # Alerts sent for a zone
    @zones_loading              = 0
    @zone_save_lock             = false
    @pending_zone_shutdown      = false
    @connections                = {}
    @document                   = nil # Mongo model
    @ip                         = nil
    @port                       = nil
    @benchmarks                 = {}
    @analyzed_benchmarks        = {}
    @exit_code                  = 0
    @chats                      = ThreadSafe::Array.new
    @logs                       = ThreadSafe::Array.new
    @inventory_changes          = []
    @inventory_changes_lock     = Mutex.new
    @enabled_products           = []
    @schedule                   = Schedule::Manager.new

    @pid                        = Process.pid

    @shutting_down              = false
    @shutting_down_parameters   = {}

    if %w{no false NO FALSE}.include?(ENV['LIQUID'])
      p "Liquid disabled."
    else
      @liquid_enabled = true
    end

    @steam_enabled = true
    @log_enabled = (ENV['LOG'] || '').downcase != 'false'

    @player_queue = EM::Queue.new
    @player_queue.pop {|p| load_player(p) }
  end

  def boot!(port = ENV['PORT'])
    @port = port || 5000
    @version = File.open("#{Deepworld::Env.root}/VERSION", "r").read

    # Open up the syslog
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS)

    EM.epoll
    EM.run do
      # hit Control + C to stop
      unless Deepworld::Env.test?
        Signal.trap("INT") { request_shutdown }
        Signal.trap("TERM") { request_shutdown }
      end

      EM.error_handler do |e|
        if defined?(Game)
          Game.info({error: "Error raised during event loop: #{e.message} (#{e.backtrace.first(4).join(", ")})", exception: e, backtrace: e.backtrace}, true)
        else
          puts "Error raised during event loop:\n#{e.message}\n#{e.backtrace.join("\n")}"
        end
      end

      MongoModel.connect do
        @ip = ENV['IP'] || IP.get_ip

        Server.register(@ip, @port, ipv6_address) do |server|
          @document = server
          @dispatcher = Dispatch::Dispatcher.new

          GameConfiguration.new do |config|
            @config = config
            @kernel_config = ZoneKernel::Config.new(config.items)

            # Behavior
            Rubyhave.configure File.expand_path('../../config/rubyhave.yml', __FILE__)

            # Loot
            loots = YAML.load_file(File.join(File.dirname(__FILE__), '../models/rewards/loot.yml'))
            loots.each do |l|
              l['type'] = 'wardrobe' if l['wardrobe']
            end
            Game.loot = loots

            # Listen for client connections, retry up to 10 times
            startup_trys = 0

            begin
              EM.start_server '0.0.0.0', @port, Connection
            rescue
              startup_trys += 1
              if startup_trys < 10
                sleep 1
                retry
              end
            end

            EM.add_periodic_timer(0.01)  { behave! }
            EM.add_periodic_timer(0.025) { track_entities! }
            EM.add_periodic_timer(0.125) { step! }
            EM.add_periodic_timer(1.0)   { kick_idle_players }
            EM.add_periodic_timer(0.5)   { shutdown!}
            EM.add_periodic_timer(1.0)   { report_server_stats }
            EM.add_periodic_timer(1.0)   { check_server_updates }
            EM.add_periodic_timer(1.0)   { write_server_logs }
            EM.add_periodic_timer(5.0)   { write_inventory_changes }
            EM.add_periodic_timer(5.0)   { store_chats }
            EM.add_periodic_timer(10.0)  { zone_report }
            EM.add_periodic_timer(30.0)  { zone_check }
            EM.add_periodic_timer(30.0)  { check_posts }
            EM.add_periodic_timer(15.0)  { analyze_benchmarks }
            EM.add_periodic_timer(0.02)  { health }
            EM.add_periodic_timer(1.0)   { shutdown_idle_zones! }
            EM.add_periodic_timer(1.0)   { persist_zones! }
            EM.add_periodic_timer(60.0)  { persist_inventory! }
            EM.add_periodic_timer(300.0) { persist_players! false }
            EM.add_periodic_timer(60.0)  { persist_players! true }
            EM.add_periodic_timer(45.0)  { refresh_online_players }
            EM.add_periodic_timer(5.0)   { kick_marked_players }
            EM.add_periodic_timer(1.0)   { @schedule.expire }
            EM.add_periodic_timer(Deepworld::Env.production? ? 600.0 : 30.00) { @config.refresh_products }

            refresh_online_players

            info "Listening on #{@ip}:#{@port}.", true
            log_to_db! :boot

            unless Deepworld::Env.test?
              binding.remote_pry "127.0.0.1", @port.to_i + 100
            end
          end
        end
      end
    end
  end

  def document_name
    @document.name
  end

  def document_id
    @document.id
  end

  def address_hash
    { 'ip_address' => @ip, 'port' => @port }
  end

  def address
    "#{@ip}:#{@port}"
  end

  def ipv6_address
    `ip -6 addr show`.split("\n").find{ |line| line.match(/global/) }.split(" ").find{ |word| word.match(/(\w+\:+)+/) } rescue nil
  end

  # Drops a player onto the load queue
  def register_player(player)
    @player_queue.push(player)
  end

  # Guard against a failure by always popping the next player
  def pop_player_after(&block)
    begin
      yield
    rescue Exception => e
      Game.info exception: e, backtrace: e.backtrace
    ensure
      @player_queue.pop {|p| load_player(p) }
    end
  end

  def load_player(player)
    zone_id = player.try(&:zone_id)

    if @shutting_down
      pop_player_after { player.connection.kick(nil, false) }

    elsif zone_id.nil?
      pop_player_after { Teleportation.spawn!(player) }

    elsif @zones[zone_id]
      pop_player_after { start_player zone_id, player }

    else
      @zones_loading += 1

      load_zone(zone_id) do |status|
        @zones_loading -= 1

        pop_player_after do
          case status
          when LoadStatus::SUCCESS
            start_player zone_id, player
          when LoadStatus::FAILURE
            player.connection.kick("World load failure.", false)
          when LoadStatus::FATAL
            Teleportation.spawn!(player)
          when LoadStatus::REROUTE
            player.connection.kick("Sending you to another server.", true)
          when LoadStatus::STUCK
            player.connection.kick("World loading issue, try again in a moment.", false)
          else
            player.connection.kick("Unknown error, try again in a moment.", false)
          end
        end
      end
    end
  end

  def start_player(zone_id, player)
    # Mark as having played
    player.played = true

    # Swap or add connection
    if existing = find_player(player.id)
      swap_connection(player, existing)
    else
      add_connection(player.connection, zone_id) if @zones[zone_id].add_player(player)
    end
  end

  def load_zone(zone_id)
    Zone.find_by_id(zone_id, callbacks: false) do |zone|
      if zone.nil?
        info message: "Zone load failure, no zone found for id.", zone: zone_id
        yield LoadStatus::FAILURE if block_given?

      elsif zone.shutting_down_at && !Deepworld::Env.development?
        yield LoadStatus::STUCK if block_given?

      elsif @document.id != zone.server_id
        info message: "Zone load failure, wrong server for zone (doc has #{zone.server_id}).", zone: zone_id
        yield LoadStatus::REROUTE if block_given?

      else
        info message: "Registering zone #{zone.name}.", zone: zone_id

        begin
          zone.run_callbacks
          zone.play unless Deepworld::Env.test?

          @zones[zone_id] = zone
          yield LoadStatus::SUCCESS if block_given?
        rescue
          # Send an alert
          unless @alerts_sent[zone_id]
            @alerts_sent[zone_id] = true
            Alert.create :zone_load_failure, :critical, "Zone #{zone.name}(#{zone_id}) could not initialize, respawning players"
          end

          info message: "Zone load failure, could not initialize, respawning players.", zone: zone_id, backtrace: $!.backtrace
          p "Zone load failure: #{$!} -- #{$!.backtrace}" if Deepworld::Env.development?
          yield LoadStatus::FATAL if block_given?
        end
      end
    end
  end

  def find_player(player_id)
    players.select{|p| p.id == player_id}.try(:first)
  end

  # Add a connection to this zone
  def add_connection(connection, zone_id)
    @connections[zone_id] ||= []
    @connections[zone_id] << connection
  end

  # Swap play connection if player has logged in from another device
  def swap_connection(new_player, existing_player)
    if (zone_id = existing_player.zone.id)
      # Remove previous connection
      existing_player.connection.close(true)
      remove_connection(existing_player.connection, zone_id)

      # Replace the players connection
      new_connection = new_player.connection

      add_connection(new_connection, zone_id)
      existing_player.connection = new_connection
      new_connection.player = existing_player

      # Send initial messages
      existing_player.zone_changed!
    else
      # Should not ever happen
      new_player.connection.close
    end
  end

  # Remove the connection from the zone
  def remove_connection(connection, zone_id)
    return unless connection
    @connections[zone_id].delete(connection) if @connections[zone_id]
  end

  def health
    add_benchmark :health, Time.now - @health_tick if @health_tick
    @health_tick = Time.now
  end

  def step!(force = false)
    add_benchmark :game_server_step do
      @zones.dup.each_value do |zone|
        zone.step!(force)
      end
    end
  end

  def behave!
    begin
      t = Time.now
      if @last_behaved_at
        @zones.dup.each_value do |zone|
          zone.behave! t - @last_behaved_at
        end
      end
      @last_behaved_at = t
    rescue Exception => e
      Game.info message: "Game server behave error", exception: e, backtrace: e.backtrace
    end
  end

  def track_entities!
    begin
      players.each do |player|
        player.send_entity_positions
      end
    rescue Exception => e
      Game.info message: "Game server track_entities error", exception: e, backtrace: e.backtrace
    end
  end

  def kick_idle_players
    # Kick non-responding clients
    add_benchmark :kick_idle_players do
      players.each do |player|
        if player.session_play_time > 30.seconds && player.last_heartbeat_at
          heartbeat_interval = Time.now - player.last_heartbeat_at

          if heartbeat_interval >= player.heartbeat_timeout && ENV['KICK'] != 'no'
            player.kick("You've timed out.", true)
            Game.info message: "Player #{player.name} kicked due to timeout."
          end
        end
      end
    end
  end

  def play
    @zones.dup.each_value do |zone|
      zone.play
    end
  end

  def pause
    @zones.dup.each_value do |zone|
      zone.pause
    end
  end

  def shutdown_idle_zones!
    return if @zone_save_lock

    add_benchmark :shutdown_idle_zones do
      spin_down_time = ENV['SPINDOWN'] ? ENV['SPINDOWN'].to_i.seconds : (ENV['VANILLA'] ? 10.minutes : Deepworld::Settings.zone.spin_down.minutes)

      # One at a time
      zone = zones.values.select do |zone|
        !zone.shutting_down_at && (zone.last_activity_at <= (Time.now - spin_down_time))
      end.random

      # If a zone and not locked
      if zone && @zone_save_lock == false
        @zone_save_lock = true

        EM.defer do
          msg = "Shutting down zone #{zone.name}(#{zone.id}) due to inactivity."
          info msg
          puts msg if ENV['SPINDOWN']
          zone.shutdown! do
            @zone_save_lock = false
          end
        end
      end
    end
  end

  def persist_zones!
    return if @zone_save_lock

    # One at a time
    zone = zones.values.select do |zone|
      !zone.shutting_down_at && zone.last_saved_at && (zone.last_saved_at <= (Time.now - Deepworld::Settings.zone.save_interval.minutes))
    end.random

    # If a zone and not locked
    if zone && @zone_save_lock == false
      @zone_save_lock = true

      EM.defer do
        begin
          zone.persist!
        rescue Exception => e
          Game.info message: "Zone save failure '#{zone.name}' file #{zone.data_path}: #{e.message}", zone: zone.id.to_s, backtrace: $!.backtrace
        end

        @zone_save_lock = false
      end
    end
  end

  def persist_inventory!
    to_save = players.map(&:id)
    return if to_save.length == 0

    # Spread saves out over 10 seconds
    EMExt.spread(10, to_save.length) do |timer|
      if player = find_player(to_save.slice!(0))
        add_benchmark :persist_inventory do
          player.inv.save!
        end
      end
    end
  end

  def persist_players!(incremental = false)
    to_save = players.map(&:id)
    return if to_save.length == 0

    # Spread saves out over 10 seconds
    EMExt.spread(10, to_save.length) do |timer|
      if player = find_player(to_save.slice!(0))
        add_benchmark :persist_player do
          if incremental
            player.save_incremental!
          else
            player.save!
          end
        end
      end
    end
  end

  def refresh_online_players
    Configuration.where(key: 'players_online').first do |players_online|
      add_benchmark :refresh_online_players do
        @players_online = Hashie::Mash.new(players_online.try(:data) || {})
        @players_online.each_pair do |id, pl|
          pl.id = BSON::ObjectId(id)
        end

        to_refresh = players.map(&:id)
        if to_refresh.length > 0
          # Spread refreshes out over 10 seconds
          EMExt.spread(10, to_refresh.length) do |timer|
            if player = find_player(to_refresh.slice!(0))
              player.send_players_online_message
            end
          end
        end
      end
    end
  end

  def kick_marked_players
    # Configuration.where(key: 'players_to_kick').first do |players_to_kick|
    #   if players = players_to_kick.try(:data)

    #   end
    # end
  end

  def analyze_benchmarks
    add_benchmark :analyze_benchmarks do
      @analyzed_benchmarks = @benchmarks.inject({}) do |hash, bench|
        times = bench[1]
        hash[bench[0]] = [times.min, times.mean, times.max].map{ |b| (b * 1000).round(2) }
        hash
      end

      @benchmarks.clear
    end

    # Persist current benchmarks to document
    @document.update( benchmarks: @analyzed_benchmarks )

    # Save any slow benchmarks to database
    @analyzed_benchmarks.each_pair do |name, bench|
      slow_benchmarks = []
      t = Time.now
      if bench[2] > 1000 && ![:game_server_step, :health].include?(name)
        slow_benchmarks << {
          'key' => 'slow_benchmark',
          'message' => "#{name} ran for #{bench[2].to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}ms",
          'server_ip' => "#{@document.ip_address}:#{@document.port}",
          'zone_ids' => zones.keys,
          'created_at' => t,
          'level' => bench[2] >= 10000 ? 'critical' : 'info',
          'data' => { 'name' => name, 'max' => bench[2], 'mean' => bench[1], 'min' => bench[0] }
        }
      end
      Alert.insert slow_benchmarks if slow_benchmarks.present?
    end
  end

  # Report high level server statistics and machine utilization
  def report_server_stats
    details = {
      reported_at: Time.now,
      pid: @pid,
      zones_count: zone_count,
      players_count: players.count,
      median_player_latency: median_player_latency,
      connections_count: EM.connection_count,
      player_queue: @player_queue.size,
      active: true,
      version: @version,
      cfg_timestamp: Game.config.timestamp
    }

    @document.update(details)
  end

  def median_player_latency
    players.map(&:latency).compact.median
  end

  def zone_count
    @zones.count + @zones_loading
  end

  def track_inventory_change(player, action, item, quantity, position = nil, other_player = nil, other_item = nil, other_quantity = nil)
    item = Game.item(item) if item.is_a?(Fixnum)

    if item && (item.track || action == :give || action == :trade)
      change = {
        p: player.id,
        z: player.zone.id,
        a: action,
        i: item.code,
        q: quantity,
        tq: player.inv.quantity(item.code),
        d: Time.now
      }
      change[:l] = (position.is_a?(Vector2) ? position.to_a : position) if position
      change[:op] = other_player.id if other_player
      if other_item
        other_item_code = other_item.is_a?(Fixnum) ? other_item : other_item.code
        change[:oi] = other_item_code
        change[:otq] = player.inv.quantity(other_item_code)
      end
      change[:oq] = other_quantity if other_quantity

      @inventory_changes_lock.synchronize do
        @inventory_changes << change
      end
    end
  end

  def clear_inventory_changes
    @inventory_changes_lock.synchronize do
      @inventory_changes.clear
    end
  end

  def write_inventory_changes
    @inventory_changes_lock.synchronize do
      if @inventory_changes.present?
        InventoryChange.collection.insert @inventory_changes
        @inventory_changes.clear
      end
    end
  end

  def log_to_db!(type, zone = nil, data = nil)
    ServerLog.create created_at: Time.now, server_id: document_id, type: type.to_s, zone_id: zone ? zone.id : nil, data: data
  end

  # Don't call this directly, use Game.info
  def log!(l)
    data = Yajl::Encoder.encode(l).gsub(/\%/, '(per)') # Replace percent sign to avoid syslog error
    Syslog.log(Syslog::LOG_INFO, data)
  end

  # Write the logs out to the syslog
  def write_server_logs(&block)
    add_benchmark :write_server_logs do
      # Send logs
      if @logs.present?
        EM.defer do
          begin
            @logs.shift(@logs.length).each { |l| self.log!(l) } unless Deepworld::Env.test?
          rescue Exception => e
            Game.info error: "Syslog error", exception: e
          end
        end
      end

      yield if block_given?
    end
  end

  def store_chats(&block)
    add_benchmark :store_chats do
      if @chats.present?
        Chat.collection << @chats.shift(@chats.length)
      end
    end

    yield if block_given?
  end

  # Look for server updates in the database
  def check_server_updates
    return if @shutting_down

    add_benchmark :check_server_updates do

      # Check for restart, maintenance, and happenings
      @document.reload do |doc|
        if doc
          # Set maintenance message
          self.maintenance = doc.maintenance

          if doc.restart || doc.transition
            @shutting_down = true
            info "Server restart requested"

            # We want to trigger a restart (lets try 42)
            request_shutdown(true, doc.transition == true)
          end
        end
      end
    end
  end

  def check_posts
    Post.sort(:published_at, :desc).limit(5).all do |posts|
      if posts.present?
        players.each do |player|
          player.send_posts posts if player.session_play_time > 5.minutes
        end
      end
    end
  end

  def zone_report
    return if @zones.blank?

    add_benchmark :zone_report do
      @zones.dup.each_value { |zone| zone.report! }
    end
  end

  def zone_check
    return if @zones.blank?

    add_benchmark :zone_check do
      @zones.dup.each_value { |zone| zone.check! unless zone.shutting_down_at }
    end
  end

  def maintenance=(maint)
    if @maintenance != maint
      @maintenance = maint

      # If new maintenance, send out messages immediately. Future player logins will get message on login
      if @maintenance.present?
        notify_all @maintenance, 503
      end
    end
  end

  # Send messages out to connections
  def queue_message(zone_id, message, chunk_index = nil)
    if connections = @connections[zone_id]
      connections.each do |conn|
        if chunk_index.nil? || conn.player.active_in_chunk?(chunk_index)
          conn.queue_message message
        end
      end
    end
  end

  def log_chat(zone, player, recipient = nil, message)
    chat = { zone_id: zone.id, player_id: player.id, message: message, created_at: Time.now }
    chat[:recipient] = recipient.id if recipient
    chat[:muted] = true if player.muted
    @chats << chat
  end

  def info(data, force = false)
    return unless @log_enabled || force

    data = { message: data } if data.is_a?(String)
    data[:message] = "#{Time.now.to_s}: #{data[:message]}"
    data[:e] = "s_#{Deepworld::Env.environment[0]}"
    data[:server] = "#{@ip}:#{@port}"

    # Stringification
    [:exception, :player_id, :zone, :zone_id].each do |k|
      data[k] = data[k].to_s if data[k]
    end

    if force || data[:exception]
      p data[:message]
      p data[:error] if data[:error]
      p data[:exception] if data[:exception]
      if backtrace = data[:backtrace]
        backtrace.first(20).each{ |b| puts b }
      end
    end

    # Abbreviation
    data.keys.each do |k|
      data[LOG_ABBREVIATIONS[k]] = data.delete(k) if LOG_ABBREVIATIONS[k]
    end

    @logs << data
  end

  def add_benchmark(name, time = nil, &block)
    if block
      time = Time.now
      yield block
      time = Time.now - time
    end

    begin
      @benchmarks[name] ||= []
      @benchmarks[name] << time

      if Deepworld::Env.development? && name != :health && time > 0.1
        p "Slow benchmark: #{name} #{(time * 1000).to_i}ms"
      end
    rescue
    end
  end

  def players
    @zones.values.collect(&:players).flatten
  end

  def notify_all(message, status=nil)
    players.each { |p| p.connection.notify(message, status) }
  end

  # Make sure you mean to call this
  def kill!
    store_chats do
      write_server_logs do
        @document.unregister do
          msg = "Server #{@document.name} shutdown."
          Game.info msg, false
          puts msg

          EM.stop_event_loop
        end
      end
    end
  end

  # With gdb:
  # (gdb) ruby eval EM.instance_variable_get(:@threadpool).size
  # 20
  # (gdb) ruby eval EM.instance_variable_get(:@threadqueue).num_waiting
  # 19
  # And since defers_finished returns false on this:
  # return false if @threadpool and @threadqueue.num_waiting != @threadpool.size
  # it's permo fucked... we need something like this, but this dont work

  # def on_defers_finished(&block)
  #   tickloop = EM.tick_loop do
  #     :stop if EM.defers_finished?
  #   end

  #   tickloop.on_stop { yield }
  # end

  def request_shutdown(restart = true, client_reconnect = false)
    Game.info "Shutdown requested #{Time.now.to_s}. restart: #{restart == true}, client_reconnect: #{client_reconnect == true}"
    @shutting_down = true
    @shutting_down_parameters = {restart: restart, client_reconnect: client_reconnect}
  end

  def shutdown!
    return unless @shutting_down || @shutting_down_parameters[:started_at]

    self.exit_code = @shutting_down_parameters[:restart] ? 42 : 0
    @shutting_down_parameters[:started_at] = Time.now

    begin
      if @zones.empty?
        self.kill!
      else
        sd = Proc.new do |reconnect|
          @zones.values.dup.each do |zone|
            zone.shutdown!(true, reconnect) do
              # Give it a couple seconds to finish writes, and kill the server
              EM.add_timer(2){ self.kill! } if @zones.empty?
            end
          end
        end

        if @shutting_down_parameters[:client_reconnect]
          Game.info "Transitioning game server #{@document.name}!"
          notify_all "Please wait, changing servers...", 503

          sd.call(true)
        else
          Game.info "Shutting down game server #{@document.name}!"
          sd.call(false)
        end
      end
    rescue Exception => e
      Game.info error: "Game shutdown failure", exception: e
    end
  end

  def code_keys(hash)
    Hash[hash.map {|k, v| [Game.item_code(k).to_s, v] }.select{|item| !item[0].nil?}]
  end


  def entity(name)
    Game.config.entities[name]
  end

  def entity_by_code(code)
    Game.config.entities.values.find{ |e| e.code == code }
  end

  def id
    @document.id
  end

  def happening(type)
    if hap = happenings[type]
      if !hap["expire_at"] || Time.now < hap["expire_at"]
        return hap
      end
    end
    false
  end

  def happenings
    @document.happenings || {}
  end

  #-----------------
  # Stuff that shouldn't be in game server dot rb
  #-----------------

  def attack_types
    %w{bludgeoning slashing piercing crushing ink} + elemental_attack_types
  end

  def elemental_attack_types
    %w{acid fire cold energy}
  end

  def fake(type, degree = 0)
    @fake ||= YAML.load_file(File.join(File.dirname(__FILE__), '../config/fake.yml'))['fake']
    @fake_first_names ||= @fake['male first names'] + @fake['female first names']
    @fake_last_names ||= @fake['last names']

    case type
    when :name then "#{@fake_first_names.random} #{@fake_last_names.random}"
    when :male_name then "#{@fake['male first names'].random} #{@fake_last_names.random}"
    when :female_name then "#{@fake['female first names'].random} #{@fake_last_names.random}"
    when :first_name then @fake_first_names.random
    when :male_first_name then @fake['male first names'].random
    when :female_first_name then @fake['female first names'].random
    when :last_name then @fake_last_names.random
    when :salutation
      case degree
      when 0 then @fake['salutations']['neutral'].random
      when 1 then @fake['salutations']['friendly'].random
      when -1 then @fake['dismiss']['unfriendly'].random
      end
    when :react
      @fake['react'].random
    else
      if opts = @fake[type.to_s]
        opts.random
      end
    end
  end

end
