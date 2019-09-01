require 'spec_helper'
include EntityHelpers

describe Minigames::Deathmatch, :pending do

  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @two, @t_sock = auth_context(@zone)
    @three, @e_sock = auth_context(@zone)
    @four, @f_sock = auth_context(@zone)

    @gun = Game.item('tools/gun-flame')

    [@one, @two, @three].each_with_index do |player, idx|
      player.position = Vector2[idx, 5]
      add_inventory(player, 922)
      add_inventory(player, @gun.code, 1, 'h')
    end
    @four.position = Vector2[75, 0]

    @zone = Game.zones[@zone.id]

    extend_player_reach @one, @two, @three, @four
  end

  context 'with an active deathmatch' do

    before(:each) do
      Minigames::Deathmatch.stub(:default_range).and_return(20)
      Minigames::Deathmatch.stub(:default_duration).and_return(10.minutes)

      cmd = BlockPlaceCommand.new([5, 5, FRONT, 922, 0], @one.connection)
      cmd.execute!
      cmd.errors.should == []

      @deathmatch = @zone.minigames.first
      @deathmatch.should_not be_blank
    end

    it 'should start a round of deathmatch' do
      @deathmatch.should_not be_blank
      @deathmatch.creator.should == @one
      @deathmatch.origin.should == Vector2[5, 5]

      status = Message.receive_one(@o_sock, only: :minigame)
      status.should_not be_blank
      status = status.data.first
      status['!'].should == 1
      status['c'].should == @one.entity_id
      status['o'].should == [5, 5]
      status['p'].should =~ [@one, @two, @three].map(&:entity_id)
      status['d'].should == 10.minutes

      meta = Message.receive_one(@o_sock, only: :block_meta)
      meta.data.should eq [[5, 5, { 'i' => 922, 'r' => 20, 'p' => @one.id.to_s }]]
    end

    it 'should include a list of participants who are in range at start' do
      @deathmatch.participants.should =~ [@one, @two, @three]
    end

    it 'should track kills' do
      3.times { pvp_kill @one, @two }
      2.times { pvp_kill @two, @one }
      1.times { pvp_kill @three, @one }

      @one.casualties.should == { @two.id.to_s => 2, @three.id.to_s => 1 }
      @one.kills.should == { @two.id.to_s => 3 }
    end

    it 'should terminate after a set time' do
      @zone.step_minigames 10.minutes + 1

      @deathmatch.should be_complete
      @zone.minigames.should be_blank
    end

    it 'should send minigame status updates after each kill' do
      first_status = Message.receive_one(@o_sock, only: :minigame)

      pvp_kill @one, @two
      kill_status = Message.receive_one(@o_sock, only: :minigame)
      kill_status.data.should == [{ 't' => 10.minutes, '$' => { @one.entity_id => [1, 0], @two.entity_id => [0, 1], @three.entity_id => [0, 0] }}]
    end

    it 'should concede a player if they disconnect' do
      @one.connection.close
      @deathmatch.participants.should_not include(@one)
    end

    it 'should send minigame status upon completion' do
      first_status = Message.receive_one(@o_sock, only: :minigame)
      pvp_kill @one, @two
      kill_status = Message.receive_one(@o_sock, only: :minigame)

      @zone.step_minigames 10.minutes + 1
      final_status = Message.receive_one(@o_sock, only: :minigame)
      final_status.data.should == [{ '!' => 2, '$' => { @one.entity_id => [1, 0], @two.entity_id => [0, 1], @three.entity_id => [0, 0] }}]
    end

    it 'should destroy the obelisk upon completion' do
      @zone.step_minigames 10.minutes + 1

      @zone.peek(5, 5, FRONT)[0].should == 0
    end

    it 'should respawn players at the obelisk' do
      @two.position = Vector2[20, 20]
      pvp_kill @one, @two
      @two.position.should == Vector2[5, 5]
    end

    pending 'should notify a player that they have left the deathmatch boundary' do

    end

    pending 'should send status every 30 seconds' do
      first_status = Message.receive_one(@o_sock, only: :minigame)

      @zone.step_minigames 31.seconds
      step_status = Message.receive_one(@o_sock, only: :minigame)
      step_status.data.first['t'].should == 10.minutes - 31.seconds

      @zone.step_minigames 61.seconds
      step_status = Message.receive_one(@o_sock, only: :minigame)
      step_status.data.first['t'].should == 10.minutes - 61.seconds
    end

  end

end