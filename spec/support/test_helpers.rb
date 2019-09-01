module TestHelpers
  require File.expand_path('../dialog_helpers.rb', __FILE__)
  include DialogHelpers

  def connect
    begin
      return TCPSocket.new("localhost", PORT)
    rescue
      raise "TCP Connection Error: #{$!}"
    end
  end

  def login(zone, player_id)
    auth_context(zone, {id: player_id})
  end

  def auth_context(zone, player_attributes={})
    player, socket = initialize_player(zone, player_attributes)

    to_get = [2,17,17,4,5,18,33,35,39,44]
    setup_messages = []
    extra_messages = []
    while !to_get.empty?
      message = Message.receive_one(socket)
      if to_get.include?(message.ident)
        setup_messages << message
        to_get.delete_at to_get.index(message.ident)
      else
        extra_messages << message
      end
    end

    ingame_player = Game.zones[zone.id].find_player(player.name)
    ingame_player.socket = socket
    raise "Socket is nil" unless ingame_player.socket.present?
    [ingame_player, socket, extra_messages, setup_messages]
  end

  def failed_login?(zone, player_attributes={})
    collection(:zone).update({_id: zone.id}, { '$set' => {server_id: Game.id}})

    if player_attributes[:id]
      player = get_player(player_attributes[:id])
    else
      player = PlayerFoundry.create({zone_id: zone.id}.merge(player_attributes))
    end

    socket = connect

    msg = Message.new(:authenticate, ['9.9.9', player.name, player.auth_tokens.first])
    msg.send(socket)

    if kick = Message.receive_one(socket, timeout: 1)
      return kick.data.first
    else
      return false
    end
  end

  def initialize_player(zone, player_attributes={})
    collection(:zone).update({_id: zone.id}, { '$set' => {server_id: Game.id}})

    if player_attributes[:id]
      player = get_player(player_attributes[:id])
    else
      player = PlayerFoundry.create({zone_id: zone.id}.merge(player_attributes))
    end

    socket = connect

    msg = Message.new(:authenticate, ['9.9.9', player.name, player.auth_tokens.first])
    msg.send(socket)

    count = 0
    while !Game.zones[zone.id] || !Game.zones[zone.id].find_player(player.name)
      raise "Player initialization failure" if count > 60
      count = count + 1
      sleep 0.01
    end

    raise "Player initialization failure" unless player && socket

    [player, socket]
  end

  def get_player(player_id)
    player_doc = collection(:players).find_one(player_id)
    Player.new(player_doc)
  end

  def extend_player_reach(*players)
    [*players].each do |player|
      player.stub(:max_mining_distance).and_return(9999)
      player.stub(:max_placing_distance).and_return(9999)
      player.stub(:attack_range).and_return(9999)
      player.stub(:can_mine_through_walls?).and_return(true)
    end
  end

  def server_wait
    connected = false

    while !connected
      socket = connect rescue nil

      if socket
        # Try and login, and get kicked
        request = Message.new(:authenticate, ['9.9.9', 'nobody', 'nope'])
        request.send(socket)
        messages = Message.receive_many(socket)
        disconnect(socket)
        connected = true
      end
    end
  end

  def reactor_wait
    # Try and login, and get kicked
    request = Message.new(:authenticate, ['9.9.9', 'nobody', 'nope'])
    request.send(socket = connect)
    messages = Message.receive_many(socket)
    disconnect(socket)
  end

  def disconnect(socket)
    socket.close
  end

  def db_connection
    if DB_CONNECTIONS.count == 0
      # Get test connection to mongo
      settings = Deepworld::Settings.mongo
      DB_CONNECTIONS << Deepworld::DB.connect(settings.hosts, settings.database, settings.username, settings.password)
    end

    DB_CONNECTIONS[0]
  end

  def collection(collection_name)
    db_connection[collection_name.to_s.underscore.pluralize]
  end

  def clean_mongo!(options = {})
    raise "Something is fucked with Deepworld::Env, not cleaning mongo!" unless Deepworld::Env.test?

    colls = [:access_codes, :alerts, :campaigns, :characters, :chats, :competitions, :configurations, :feed_items, :flags, :game_stats, :guilds, :inventory_changes, :invites, :job_histories, :job_requests, :landmarks, :machine_stats, :machines, :minigame_records, :missives, :order_memberships, :player_notes, :players, :products, :purchase_receipts, :purchases, :push_notifications, :redemption_codes, :server_logs, :server_stats, :servers, :sessions, :specs, :transactions, :users, :zones]

    if options[:except]
      colls = colls - [options[:except]]
    end

    colls.each { |coll| db_connection.collection(coll).drop }
  end

  def find_item(zone, item_id, layer)
    find_items(zone, item_id, layer, 1).first
  end

  def find_items(zone, item_id, layer, count = nil)
    items = []
    (0..(zone.size.y - 1)).each do |y|
      (0..(zone.size.x - 1)).each do |x|
        items << Vector2.new(x, y) if zone.peek(x, y, layer)[0] == item_id
        return items if count and items.count >= count
      end
    end
    return items
  end

  def stub_epoch_ids(*players)
    players.each_with_index do |p, idx|
      p.stub(:epoch_id).and_return(Time.now.to_i + idx)
    end
  end

  def stub_item(name = 'item', data = nil)
    Game.config.test[:next_item_code] ||= 2000

    data = { 'id' => name, 'name' => name, 'code' => Game.config.test[:next_item_code], 'title' => name.titleize, 'block_size' => [1, 1] }.merge(data || {})
    Game.config.items[name] = data
    item = Game.config.items[name]
    Game.config.send(:configure_item!, name, item)
    Game.config.test[:next_item_code] += 1

    get_item(name)
  end

  def add_inventory(player, item_id, amount = 1, container = 'i', index = 0)
    # Lookup item if name givem
    if item_id.to_i.to_s != item_id.to_s
      item_id = Game.item_code(item_id)
    end

    player.inv.add(item_id, amount)
    if container != 'i'
      player.inv.move(item_id, container, index)
    end
  end

  def get_item(name)
    Game.item(name.to_s)
  end

  def get_item_code(name)
    Game.item(name.to_s).code
  end

  def stub_entity(name = 'creature', data = nil)
    Game.config.test[:next_entity_code] ||= 990

    data = { 'code' => Game.config.test[:next_entity_code], 'health' => 1.0, 'name' => name }.merge(data || {})
    Game.config.entities[name] = data
    Game.config.test[:next_entity_code] += 1

    get_entity(name)
  end

  def get_entity(name)
    Game.entity(name)
  end

  def time_travel(shift_amount)
    stub_date(Time.now + shift_amount)
  end

  def stub_date(date)
    time = date.to_time

    Time.stub(:now).and_return(time)
    Date.stub(:now).and_return(time)
    Ecosystem.stub(:time).and_return(time)

    time
  end

  def reload_zone(zone)
    Game.zones[zone.id]
  end

  def shutdown_zone(zone)
    zone = Game.zones[zone.id]
    @shutdown ||= {}

    zone.shutdown! do |z|
      @shutdown[z.id] = true
    end

    eventually { @shutdown[zone.id].should eq true }
  end

  def call_on_range(from, to, &block)
    index = -1
    (from[0]..to[0]).each do |x|
      (from[1]..to[1]).each do |y|
        yield x, y, index += 1
      end
    end
  end

  def command(player, type, arguments)
    type = "#{type.to_s.camelize}Command".constantize if type.is_a?(Symbol)
    cmd = type.new(arguments, player.connection)
    cmd.execute!
    cmd
  end

  def command!(player, type, arguments)
    cmd = command(player, type, arguments)
    cmd.errors.should eq([]), "#{type} command had errors: #{cmd.errors}"
    cmd.exception.should eq nil
    cmd
  end

  def receive_msg(player, type)
    Message.receive_one(player.socket, only: type)
  end

  def receive_many(player, type = nil)
    opts = {}
    opts[:only] = type if type

    Message.receive_many(player.socket, opts)
  end

  def receive_msg!(player, type)
    msg = receive_msg(player, type)
    msg.should_not be_nil, "No #{type} message received"
    msg.should be_message(type)
    msg
  end

  def receive_msg_string(player, type)
    receive_msg(player, type).data.to_s
  end

  def receive_msg_string!(player, type)
    receive_msg!(player, type).data.to_s
  end

  def console!(player, command, args = [], confirm = false)
    command player, :console, [command.to_s, args]
    respond_to_dialog player if confirm

    Message.receive_one(player.socket, only: :notification)
  end

  def with_a_zone(options = {})
    zone = ZoneFoundry.create({server_id: Game.document_id}.merge(options), {callbacks: false})
    load_zone(zone.id)
  end

  def load_zone(zone_id)
    collection(:zone).update({_id: zone_id}, { '$set' => {server_id: Game.id}})
    Game.load_zone zone_id

    eventually { Game.zones[zone_id].should_not be_nil }

    @zone = Game.zones[zone_id]
    @zone.play

    @zone
  end

  def with_a_player(zone = @zone, options = {})
    @one = register_player(zone, options)
  end

  def with_2_players(zone = @zone, options = {})
    [@one = register_player(zone, options),
      @two = register_player(zone, options)]
  end

  def with_3_players(zone = @zone, options = {})
    [@one = register_player(zone, options),
      @two = register_player(zone, options),
      @three = register_player(zone, options)]
  end

  def with_4_players(zone = @zone, options = {})
    [@one = register_player(zone, options),
      @two = register_player(zone, options),
      @three = register_player(zone, options),
      @four = register_player(zone, options)]
  end

  def register_player(zone = @zone, options = {})
    player, socket, extra_messages, setup_messages = auth_context(zone, options)
    player.stub(:extra_messages).and_return(extra_messages)
    player.stub(:setup_messages).and_return(setup_messages)
    player
  end

  def profile(prefix = "profile")
    result = RubyProf.profile { yield }

    profile_print(result)
  end

  def profile_start
    RubyProf.start
  end

  def profile_stop
    result = RubyProf.stop

    profile_print(result)
  end

  def profile_print(result)
    dir = File.join(Deepworld::Env.root, "tmp", "performance")
    FileUtils.mkdir_p(dir)

    file = File.join(dir, "prof_#{Time.now.to_s.parameterize}.html")
    open(file, "w") {|f| RubyProf::GraphHtmlPrinter.new(result).print(f, min_percent: 1) }
  end
end

# Hooks
RSpec.configure do |config|
  config.before(:each, with_a_zone: true) { with_a_zone }
  config.before(:each, with_a_zone_and_player: true) { with_a_zone; with_a_player(@zone); @player = @one; }
  config.before(:each, with_a_zone_and_2_players: true) { with_a_zone; with_2_players(@zone) }
  config.before(:each, with_a_zone_and_3_players: true) { with_a_zone; with_3_players(@zone) }
end