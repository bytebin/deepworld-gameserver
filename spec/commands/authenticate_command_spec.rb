require 'spec_helper'

describe 'Authenticate' do
  before(:each) do
    @zone = ZoneFoundry.create
    @player = PlayerFoundry.create(zone_id: @zone.id)

    @socket = connect
  end

  it 'should send a kick for a failed authentication request' do
    request = Message.new(:authenticate, ['9.9.9', @player.name, 'nope'])
    request.send(@socket)

    messages = Message.receive_many(@socket)
    messages.should be_message(:kick)
  end

  it "should send a kick message for an authentication request for a bunk zone" do
    @player = PlayerFoundry.create(zone_id: 'bloop')
    msg = Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last])
    msg.send(@socket)

    messages = Message.receive_many(@socket)
    messages.should be_message(:kick)
  end

  describe 'required versions' do

    before(:each) do
      AuthenticateCommand.stub(:default_required_version).and_return('5.0')
    end

    def test_version(auth_version, expected_version)
      msg = Message.new(:authenticate, [auth_version, @player.name, @player.auth_tokens.last])
      msg.send(@socket)

      if expected_version
        msg = Message.receive_one(@socket)
        msg.should be_message(:kick)
        msg[:should_reconnect].should eq false
        msg[:reason].should match /Version #{expected_version} is required/
      else
        eventually do
          @player.should be_initialized
        end
      end
    end

    it 'should send a kick for an old client version (using nil default)' do
      Game.config.stub(:client_version).and_return(nil)
      test_version '4.0', '5.0'
    end

    it 'should not send a kick for a current client version (using nil default)' do
      Game.config.stub(:client_version).and_return(nil)
      test_version '5.0', nil
    end

    it 'should send a kick for an old client version (using specified default)' do
      Game.config.stub(:client_version).and_return({ 'default' => '5.0', 'iPhone|iPod' => '4.0' })
      test_version '4.0', '5.0'
    end

    it 'should not send a kick for a current client version (using specified default)' do
      Game.config.stub(:client_version).and_return({ 'default' => '5.0', 'iPhone|iPod' => '6.0' })
      test_version '5.0', nil
    end

    it 'should send a kick for an old client version (using platform)' do
      Game.config.stub(:client_version).and_return({ 'default' => '4.0', 'iPad|iPod' => '5.0' })
      test_version '4.0', '5.0'
    end

    it 'should not send a kick for a current client version (using platform)' do
      Game.config.stub(:client_version).and_return({ 'default' => '5.0', 'iPad|iPod' => '4.0' })
      test_version '4.0', nil
    end

  end

  it 'should send client config, world, and position on authentication request' do
    msg = Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last])

    msg.send(@socket)
    sleep 0.25

    expected = [:client_configuration, :zone_status, :zone_status, :player_position, :skill, :health, :stat, :inventory, :wardrobe, :notification]
    messages = Message.receive_many(@socket, ignore: [:entity_position, :entity_status], max: expected.size)

    messages.should be_messages(*expected)
  end

  it 'should not report that Im connected on a second connection' do
    msg = Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last])
    msg.send(@socket)
    eventually { Game.players.count.should eq 1 }

    @socket.close
    eventually { Game.players.count.should eq 0 }

    @socket2 = connect
    msg = Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last])
    msg.send(@socket2)
    message = Message.receive_one(@socket2, only: :kick)
    message.should be_nil
  end

  it 'should send me entity status/position messages correctly after being enqueued during zone load' do
    pending 'should be removed after player loading refactor?'

    zone = ZoneFoundry.create(shutting_down_at: Time.now)

    one = PlayerFoundry.create(zone_id: zone.id)
    two = PlayerFoundry.create(zone_id: zone.id)
    o_sock = connect
    t_sock = connect

    Message.new(:authenticate, ['9.9.9', one.name, one.auth_tokens.last]).send(o_sock)
    Message.new(:authenticate, ['9.9.9', two.name, two.auth_tokens.last]).send(t_sock)

    Game.zones.size.should eq 0

    sleep 0.05
    collection(:zone).update({_id: zone.id}, {'$set' => { 'shutting_down_at' => nil}})
    Game.load_queued_zones!

    eventually do
      Game.zones.size.should eq 1
      Game.players.size.should eq 2

      o_msgs = Message.receive_many(o_sock)
      o_msgs.first.should be_a(ClientConfigurationMessage)
      o_msgs[-2].should be_a(WardrobeMessage)

      t_msgs = Message.receive_many(t_sock)
      t_msgs.first.should be_a(ClientConfigurationMessage)
      t_msgs[-3].should be_a(EntityStatusMessage)
      t_msgs[-2].should be_a(EntityPositionMessage)

      Game.players.first.entity_id.should_not eq Game.players.last.entity_id
    end

    Game.players.each{ |p| p.send_entity_positions false }

    o_msgs = Message.receive_many(o_sock)
    o_msgs[0].should be_a(EntityStatusMessage)
    o_msgs[1].should be_a(EntityPositionMessage)

    t_msgs = Message.receive_many(t_sock)
    t_msgs[0].should be_a(EntityPositionMessage)
  end

  it 'should provide messages in order' do
    register_player(@zone)
    msg = Message.new(:authenticate, ['9.9.9', @player.name, @player.auth_tokens.last])
    msg.send(@socket)

    expected = [:client_configuration, :zone_status, :zone_status, :player_position, :skill, :health, :stat, :inventory, :wardrobe, :entity_status, :entity_position, :notification]
    messages = Message.receive_many(@socket, max: expected.size).should be_messages expected
  end
end