require 'spec_helper'
include EntityHelpers

describe Behavior::Shielder, :with_a_zone_and_player do

  before(:each) do
    @entity = add_entity(@zone, 'brains/medium', 1)
    @shielder = @entity.behavior.children.find{ |b| b.is_a?(Behavior::Shielder) }
  end

  it 'should defend against all' do
    @shielder.defenses.should =~ Game.attack_types
  end

  pending 'should activate shield in response to attacks' do
    @player.update_tracked_entities
    attack_entity(@player, @entity, Game.item_code('tools/gun-flame'), true).errors.should eq []
    behave_entity @entity
    @entity.defense('fire').should eq 1.0

    shield_msg = Message.receive_one(@player.socket, only: :entity_change)
    shield_msg.should_not be_blank
    shield_msg.data.should eq([[@entity.entity_id, { 's' => 'fire' }]])
  end

  it 'should expire shield after a duration' do
    attack_entity(@player, @entity, Game.item_code('tools/gun-flame'))
    behave_entity(@entity, 20, 0.5)
    @entity.defense('fire').should < 1.0
  end

end