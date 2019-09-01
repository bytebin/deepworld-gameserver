require 'spec_helper'
include EntityHelpers

describe InventoryMoveCommand do
  before(:each) do
    with_a_zone
    with_a_player(@zone, {inventory: { '600' => [ 21, 'i', 1 ], '601' => [ 10, 'i', 2 ] }})
  end

  it 'should update inventory position' do
    command! @one, :inventory_move, [600, 'a', 4]
    @one.inv.quantity(600).should eq 21
    @one.inv.location_of(600).should eq ['a', 4]
  end

  it 'should move an existing item out of the hotbar' do
    @one.inv.add('601', 10)
    @one.inventory_locations['h'][0] = 601

    command! @one, :inventory_move, [600, 'h', 0]

    @one.inv.location_of(600).should eq ['h', 0]
    @one.inv.location_of(601).should eq ['i', -1]
  end

  it 'should move an existing item out of accessories' do
    @one.inv.add('601', 10)
    @one.inventory_locations['a'][5] = 601

    command! @one, :inventory_move, [600, 'a', 5]

    @one.inv.location_of(600).should eq ['a', 5]
    @one.inv.location_of(601).should eq ['i', -1]
  end

end