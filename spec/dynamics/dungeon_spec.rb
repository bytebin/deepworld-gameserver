require 'spec_helper'

describe Dynamics::Dungeon do
  include BlockHelpers
  include EntityHelpers

  before(:each) do
    with_a_zone
    with_2_players @zone
    extend_player_reach @one

    @guard_item = stub_item('guard_item', 'meta' => 'local', 'use' => { 'guard' => true, 'destroy' => 'guard' })

    @zone.update_block nil, 1, 1, FRONT, @guard_item.code # Dungeon 1
    @zone.update_block nil, 2, 2, FRONT, @guard_item.code # Dungeon 1
    @zone.update_block nil, 3, 3, FRONT, @guard_item.code # Dungeon 1
    @zone.update_block nil, 10, 10, FRONT, @guard_item.code # Dungeon 2

    # Link up "other" metadata for guard items
    @zone.get_meta_block(1, 1)['o'] = [[2, 2], [3, 3]]
    @zone.get_meta_block(2, 2)['o'] = [[1, 1], [3, 3]]
    @zone.get_meta_block(3, 3)['o'] = [[1, 1], [2, 2]]
    @zone.get_meta_block(10, 10)['o'] = []
  end

  describe 'legacy' do

    before(:each) do
      @zone.dungeon_master.legacy_index!
    end

    it 'should set up a zone with dungeons' do
      dungeons = @zone.dungeon_master.dungeons.values.uniq
      dungeons.size.should eq 2
      dungeons[0].guard_blocks.map(&:position).should eq [Vector2[1, 1], Vector2[2, 2], Vector2[3, 3]]
      dungeons[1].guard_blocks.map(&:position).should eq [Vector2[10, 10]]
    end

    it 'should award raider achievements for mining the last guard item in a dungeon' do
      mine_guard_items!
      @one.progress['dungeons raided'].should eq 1
      receive_msg(@one, :notification).data.to_s.should =~ /raided a dungeon/
    end

  end

  describe 'modern' do

    before(:each) do
      @zone.get_meta_block(1, 1)['@'] = 1
      @zone.get_meta_block(2, 2)['@'] = 1
      @zone.get_meta_block(3, 3)['@'] = 1
      @zone.get_meta_block(10, 10)['@'] = 2
      @zone.dungeon_master.index!
    end

    it 'should set up a modern zone with dungeons' do
      dungeons = @zone.dungeon_master.dungeons.values.uniq
      dungeons.size.should eq 2
      dungeons[0].guard_blocks.map(&:position).should eq [Vector2[1, 1], Vector2[2, 2], Vector2[3, 3]]
      dungeons[1].guard_blocks.map(&:position).should eq [Vector2[10, 10]]
    end

    it 'should award raider achievements for mining the last guard item in a dungeon' do
      mine_guard_items!
      @one.progress['dungeons raided'].should eq 1
      receive_msg(@one, :notification).data.to_s.should =~ /raided a dungeon/
    end

  end

  it 'should award dungeon progress for mining guard items' do
    pending
  end

  it 'should award dungeon progress for killing guard creatures' do
    pending
  end

  def mine_guard_items!
    mine 1, 1, @guard_item.code
    mine 2, 2, @guard_item.code
    mine 3, 3, @guard_item.code
  end

end
