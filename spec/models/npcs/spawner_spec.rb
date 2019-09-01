require 'spec_helper'
include EntityHelpers

describe Npcs::Spawner, :with_a_zone_and_player do

  before(:each) do
    @spawner = @zone.spawner
  end

  it 'should spawn creatures from maws' do
    @zone.update_block nil, 5, 5, BASE, Game.item_code('base/maw')
    @zone.stub(:immediate_chunk_indexes).and_return({0=>true})

    entities = @spawner.spawn_in_chunks([0], [[5, 'maw']])
    entities.should_not be_blank
    entities.first.config.group.should == 'creature'
  end

  it 'should spawn automata from pipes' do
    @zone.update_block nil, 5, 5, BASE, Game.item_code('base/pipe')
    @zone.stub(:immediate_chunk_indexes).and_return({0=>true})

    entities = @spawner.spawn_in_chunks([0], [[6, 'pipe']])
    entities.should_not be_blank
    entities.first.config.group.should == 'automata'
  end

  it 'should increase frequency of friendlies in easy zones' do
    freq = @spawner.spawning_patterns['creatures/crow'].frequency
    @zone.difficulty = 2
    @spawner.load_spawning_patterns
    @spawner.spawning_patterns['creatures/crow'].frequency.should > freq
  end

  it 'should decrease frequency of monsters in easy zones' do
    freq = @spawner.spawning_patterns['automata/small'].frequency
    @zone.difficulty = 1
    @spawner.load_spawning_patterns
    @spawner.spawning_patterns['automata/small'].frequency.should < freq
  end

  pending 'should spawn guards from meta blocks' do
    @zone.update_block nil, 5, 5, FRONT, Game.item_code('mechanical/protector-enemy')
    @zone.get_meta_block(5, 5).data['!'] = [201, 200] # Medium & small brain
  end

end
