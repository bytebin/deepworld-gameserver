
require 'spec_helper'

describe GameServer do

  it 'should provide client configurations' do
    cfg = Game.config.data(PlayerFoundry.create, true)
    cfg.should_not be_blank
  end

  context 'loading' do
    it 'should load several players properly' do
      @zone = ZoneFoundry.create
      3.times do |i|
        register_player @zone
      end

      Game.players.count.should eq 3
    end

    it 'should handle stuck servers correctly' do
      @zone = ZoneFoundry.create(shutting_down_at: Time.now)
      3.times.map { failed_login?(@zone).should eq 'World loading issue, try again in a moment.' }

      @zone.update(shutting_down_at: nil)
      3.times.map { register_player @zone }

      Game.players.count.should eq 3
    end
  end

  context 'with a zone and a player' do
    before(:each) do
      @zone = ZoneFoundry.create
      @one, @o_sock = auth_context(@zone, {inventory: { '600' => [ 21, 'i', 1 ], '601' => [ 10, 'i', 2 ], '1024' => [ 8, 'h', 2 ] }})
      extend_player_reach @one
    end

    it 'should persist players inventory on an interval' do
      @one.inv.add(512, 2)
      Game.persist_inventory!

      eventually { collection(:players).find_one(name: @one.name)['inventory']['512'].should eq 2 }
    end

    it 'should persist players on an interval' do
      @one.items_mined = 666
      Game.persist_players!

      eventually { collection(:players).find_one(name: @one.name)['items_mined'].should eq 666 }
    end

    it 'should report the version number' do
      version = File.open("#{Deepworld::Loader.root}/VERSION", "r").read
      Game.version.should eq version
    end

    it 'should add a players connection to server connections' do
      Game.connections[@zone.id].should eq [@one.connection]
    end

    it 'should add a new players connection to the correct has index' do
      @zone2 = ZoneFoundry.create
      @two, @t_sock = auth_context(@zone2)

      Game.connections[@zone.id].should eq [@one.connection]
      Game.connections[@zone2.id].should eq [@two.connection]
    end

    it 'should boot a player that has not heartbeated' do
      @one.stub(:session_play_time).and_return(60.seconds)
      time_travel(10.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should_not be_nil, "Didn't recieve a kick message :("
      msg[:reason].should match /You've timed out./
    end

    it 'should boot a player that has not heartbeated' do
      @one.stub(:session_play_time).and_return(60.seconds)
      time_travel(10.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should_not be_nil, "Didn't recieve a kick message :("
      msg[:reason].should match /You've timed out./
    end

    it 'should not boot a player within the first 30 seconds' do
      @one.stub(:session_play_time).and_return(5.seconds)
      time_travel(10.seconds)
      Game.kick_idle_players

      Message.receive_one(@o_sock, only: :kick).should be_blank
    end

    it 'should not boot a player that has not passed dey timeout threshhold' do
      @one.stub(:session_play_time).and_return(60.seconds)
      time_travel(9.seconds)
      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should be_nil, "Homeboy got booted and shouldn't have"
    end

    it 'should not boot a player in a tutorial zone until the beginner timeout' do
      Game.zones.first.last.static = true
      Game.zones.first.last.static_type = 'tutorial'
      
      time_travel(59.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should be_nil, "Homeboy got booted and shouldn't have"
    end

    it 'should not boot a player in a beginner zone until the beginner timeout' do
      Game.zones.first.last.scenario = 'Beginner'
      
      time_travel(59.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should be_nil, "Homeboy got booted and shouldn't have"
    end

    it 'should boot a player that has not heartbeated in a beginner zone' do
      Game.zones.first.last.scenario = 'Beginner'

      @one.stub(:session_play_time).and_return(60.seconds)
      time_travel(60.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should_not be_nil, "Didn't recieve a kick message :("
      msg[:reason].should match /You've timed out./
    end

    it 'should boot a player that has not heartbeated in a tutorial zone' do
      Game.zones.first.last.static = true
      Game.zones.first.last.static_type = 'tutorial'

      @one.stub(:session_play_time).and_return(60.seconds)
      time_travel(60.seconds)
      Game.kick_idle_players

      msg = Message.receive_one(@o_sock, only: :kick)
      msg.should_not be_nil, "Didn't recieve a kick message :("
      msg[:reason].should match /You've timed out./
    end
  end

  it 'should load a zone with some players' do
    @zone = ZoneFoundry.create
    @one = auth_context(@zone)[0]

    eventually {
      Game.zones.count.should eq 1
      Game.zones[@zone.id].should_not be_nil
      Game.players.first.should eq @one
    }
  end

  it 'should only load a zone that is not "shutting down"' do
    @zone = ZoneFoundry.create(shutting_down_at: Time.now)
    @zone.shutting_down_at.should_not be_nil

    @socket = connect
    @player = PlayerFoundry.create(zone_id: @zone.id)
    Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last]).send(@socket)

    msg = Message.receive_one(@socket)
    msg.should be_message(:kick)
    msg[:reason].should eq "World loading issue, try again in a moment."
    msg[:should_reconnect].should eq false
  end

  it 'should kick a player to reconnect to another server if rerouted' do
    @zone = ZoneFoundry.create(server_id: ServerFoundry.create.id)

    @socket = connect
    @player = PlayerFoundry.create(zone_id: @zone.id)
    Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last]).send(@socket)

    msg = Message.receive_one(@socket)
    msg.should be_message(:kick)
    msg[:reason].should eq "Sending you to another server."
    msg[:should_reconnect].should eq true
  end

  context 'with a zone and player' do
    before(:each) do
      @zone = ZoneFoundry.create
      @one, @o_sock = auth_context(@zone)
    end

    it 'should swap connections for a new authentication' do
      original_connection = @one.connection

      auth_context(@zone, {id: @one.id})

      Game.players.first.object_id.should eq @one.object_id
      Game.players.first.connection.should_not eq original_connection
      Game.connections.count.should eq 1
      Game.players.count.should eq 1
      Game.connections.values.flatten.should eq [Game.players.first.connection]
    end
  end

  it 'should spin multiple zones down after inactivity' do
    zone_count = 5

    zone_count.times do
      with_a_player ZoneFoundry.create
    end

    Game.zones.count.should eq zone_count

    time_travel(Deepworld::Settings.zone.spin_down.minutes)

    eventually do
      # Do this until they are all shutdown
      Game.shutdown_idle_zones!

      collection(:zones).count.should eq zone_count

      Game.zones.count.should eq 0

      collection(:zones).find.each do |z|
        z['shutting_down_at'].should be_nil
        z['server_id'].should be_nil
      end
    end
  end

  it 'should not get stuck when a zone spins up while shutting down' do
    with_a_zone
    with_a_player @zone

    Game.zones.count.should eq 1

    time_travel(Deepworld::Settings.zone.spin_down.minutes)
    Thread.new { Game.shutdown_idle_zones! }

    reloaded = collection(:zones).find(name: @zone.name).first
    reloaded['shutting_down_at'].should be_nil
  end
end
