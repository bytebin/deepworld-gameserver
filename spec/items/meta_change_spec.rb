require 'spec_helper'

describe Items::MetaChange do

  before(:each) do
    with_a_zone
    with_a_player @zone
    extend_player_reach @one

    @block_item = stub_item('block', { 'meta' => 'hidden' })
    @change_item_a = stub_item('change A', { 'use' => { 'meta_change' =>  { 'block' => 'block', 'append' => ['spr', 'item'] }}})
    @change_item_b = stub_item('change B', { 'use' => { 'meta_change' =>  { 'block' => 'block', 'append' => ['spr', 20] }}})

    @zone.update_block nil, 0, 0, FRONT, @change_item_a.code
    @zone.update_block nil, 1, 1, FRONT, @change_item_b.code
    @zone.update_block nil, 10, 10, FRONT, @block_item.code
  end

  it 'should append to a meta block' do
    @zone.get_meta_block(10, 10)['spr'].should be_nil

    command! @one, :block_use, [0, 0, FRONT, []]
    @zone.get_meta_block(10, 10)['spr'].should eq [@change_item_a.code]

    command! @one, :block_use, [1, 1, FRONT, []]
    @zone.get_meta_block(10, 10)['spr'].should eq [@change_item_a.code, 20]
  end

end