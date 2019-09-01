require 'spec_helper'
include EntityHelpers

describe Items::Recycler do

  before(:each) do
    @iron = Game.item_code('building/iron').to_s
    @copper = Game.item_code('building/copper').to_s
    @brass = Game.item_code('building/brass').to_s

    @iron_rubble = Game.item_code('rubble/iron').to_s
    @copper_rubble = Game.item_code('rubble/copper').to_s
    @brass_rubble = Game.item_code('rubble/brass').to_s
  end

  it 'should recycle scrap into metal', :with_a_zone_and_player do
    add_inventory(@one, @iron_rubble, 56)
    add_inventory(@one, @copper_rubble, 28)
    add_inventory(@one, @brass_rubble, 3)
    add_inventory(@one, @iron, 3)
    add_inventory(@one, @brass, 1)

    recycler = Items::Recycler.new(@one)
    recycler.stub(:scrap_per_item).and_return(5)
    recycler.use!

    @one.inv.quantity(@iron_rubble).should eq 1
    @one.inv.quantity(@copper_rubble).should eq 3
    @one.inv.quantity(@brass_rubble).should eq 3

    @one.inv.quantity(@iron).should eq 14
    @one.inv.quantity(@copper).should eq 5
    @one.inv.quantity(@brass).should eq 1
  end

  it 'should alert if player has no scrap to recycle', :with_a_zone_and_player do
    add_inventory(@one, @iron_rubble, 4)
    add_inventory(@one, @copper_rubble, 2)
    add_inventory(@one, @brass_rubble, 3)

    Items::Recycler.new(@one).use!

    msg = Message.receive_one(@one.socket, only: :notification)
    msg.data.to_s.should =~ /not have enough/
  end

end