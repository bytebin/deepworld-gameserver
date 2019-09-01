require 'spec_helper'
include EntityHelpers

describe Achievements::HuntingAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone, {inventory: { '1024' => [ 1, 'h', 1 ] }})
    @zone = Game.zones[@zone.id]
    extend_player_reach @one
  end

  describe 'Hunter achievement' do
    it 'should increment my progress when I kill 1 creature' do
      kill_entity @one, add_entity(@zone, 'terrapus/child')
      @one.progress["creatures killed"].should eq 1
    end

    it 'should give me a hunter achievement when I kill 25 creatures' do
      @entities = add_entity(@zone, 'terrapus/child', 100)
      kill_entity(@one, @entities)

      msg = Message.receive_one(@o_sock, only: :achievement)

      msg.should_not be_nil
      msg[:key].should eq ['Hunter']
      msg[:points].should eq [2000]
    end
  end
end