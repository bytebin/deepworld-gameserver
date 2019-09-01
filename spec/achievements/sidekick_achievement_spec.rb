require 'spec_helper'
include EntityHelpers

describe Achievements::HuntingAchievement do
  before (:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone, {inventory: { '1024' => [ 1, 'h', 1 ] }})
    @two, @t_sock = auth_context(@zone, {inventory: { '1024' => [ 1, 'h', 1 ] }})
    @zone = Game.zones[@zone.id]
    extend_player_reach @one, @two
  end

  it 'should increment my progress when I assist in killing 1 create' do
    entity = add_entity(@zone, 'terrapus/child')

    attack_entity @two, entity
    attack_entity @one, entity

    kill_entity @two, entity
    @one.progress["creatures maimed"].should eq 1
  end

  it 'should give me a sidekick achievement when I assist in 50 creature kills' do
    @one.progress["creatures maimed"] = 49

    entity = add_entity(@zone, 'terrapus/child')

    attack_entity @two, entity
    attack_entity @one, entity

    kill_entity @two, entity

    msg = Message.receive_one(@o_sock, only: :achievement)

    msg.should_not be_nil
    msg[:key].should eq ['Sidekick']
    msg[:points].should eq [2000]
  end
end