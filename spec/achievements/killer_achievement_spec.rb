require 'spec_helper'
include EntityHelpers

describe Achievements::KillerAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone, {inventory: { '1024' => [ 1, 'h', 1 ] }})
    @two, @t_sock = auth_context(@zone)
    @three, @e_sock = auth_context(@zone)
    stub_epoch_ids @one, @two, @three

    @zone = Game.zones[@zone.id]
    extend_player_reach @one

    48.times do |i|
      @one.kills << [i, 1]
      @one.casualties << [i, 1]
    end
  end

  it 'should give me a killer achievement when I kill 50 players in a PvP scenario' do
    @zone.pvp = true
    @two.die! @one
    @one.players_killed.should eq 49

    Message.receive_one(@o_sock, only: :achievement).should be_blank

    @three.die! @one
    @one.players_killed.should eq 50

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should_not be_nil
    msg[:key].should eq ['Killer']
    msg[:points].should eq [2000]
  end

  it 'should not give me an achievement for killing in a non-PvP scenario' do
    @zone.pvp = false
    @two.die! @one

    Message.receive_one(@o_sock, only: :achievement).should be_blank
  end

  it 'should give me the casualty achievement for being killed by 50 players' do
    @one.die! @two
    @one.players_killed_by.should eq 49

    Message.receive_one(@o_sock, only: :achievement).should be_blank

    @one.die! @three
    @one.players_killed_by.should eq 50

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should_not be_nil
    msg[:key].should eq ['Casualty']
    msg[:points].should eq [2000]
  end

end