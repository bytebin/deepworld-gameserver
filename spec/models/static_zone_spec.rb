require 'spec_helper'
include BlockHelpers

describe StaticZone do
  before(:each) do
    with_a_zone(static: true, static_type: 'tutorial', data_path: :bunker)
    with_a_player(@zone)
    extend_player_reach @one

    @item_code = 650
    @item = find_item(@zone, @item_code, FRONT)
  end

  it 'should not allow me to change a block by mining it' do
    mine(*@item, @item_code).errors.should be_blank

    item = @zone.peek(*@item, FRONT)[0]
    item.should == @item_code
  end

  it 'should not allow me to dig earth' do
    earth = Game.item_code('ground/earth')
    @zone.update_block nil, 5, 5, FRONT, earth

    @one.current_item = Game.item_code('tools/shovel')
    mine(5, 5, earth).errors.should be_blank

    @zone.peek(5, 5, FRONT)[0].should eq earth
  end

  it 'should limit my max inventory amount' do
    @zone.update_block nil, 5, 5, FRONT, 512
    @one.inventory.delete 512

    60.times { mine(5, 5, 512).errors.should be_blank }

    @one.inv.quantity(512).should eq 50
  end

end