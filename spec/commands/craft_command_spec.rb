require 'spec_helper'

describe 'Craft' do
  before(:each) do
    @zone = ZoneFoundry.create

    @copper_ore = Game.item('ground/copper-ore')
    @copper = Game.item('building/copper')
    @iron_ore = Game.item('ground/iron-ore')
    @zinc_ore = Game.item('ground/zinc-ore')
    @brass = Game.item('building/brass')
    @brass_reinforced = Game.item('building/brass-reinforced')
    @iron = Game.item('building/iron')
    @pitch = Game.item('building/pitch')

    @one, @o_sock = auth_context(@zone)
    Game.play
  end

  describe 'successfully' do

    it 'should allow an item to be crafted if the player has all ingredients' do
      add_inventory(@one, @copper_ore.code)
      add_inventory(@one, @zinc_ore.code)

      command! @one, :craft, [@brass.code]

      @one.inv.quantity(@copper_ore.code).should == 0
      @one.inv.quantity(@zinc_ore.code).should == 0
      @one.inv.quantity(@brass.code).should == 2
    end

    it 'should track inventory changes for trackable blocks' do
      @brass_reinforced.stub(:track).and_return(true)
      @one.skills['building'] = 5
      add_inventory(@one, @brass.code)
      add_inventory(@one, @iron.code)

      command! @one, :craft, [@brass_reinforced.code]

      Game.write_inventory_changes
      eventually do
        inv = collection(:inventory_changes).find.first
        inv.should_not be_blank
        inv['p'].should eq @one.id
        inv['z'].should eq @zone.id
        inv['i'].should eq @brass_reinforced.code
        inv['q'].should eq 1
      end
    end

  end

  it 'should not allow an item to be crafted if the player is missing ingredients' do
    add_inventory(@one, @copper.code, 40)
    add_inventory(@one, @iron_ore.code, 1)

    msg = Message.new(:craft, [@brass.code]).send(@o_sock)
    reactor_wait

    @one.inv.quantity(@copper.code).should eq 40
    @one.inv.quantity(@iron_ore.code).should eq 1
    @one.inv.quantity(@copper_ore.code).should eq 0
  end

  describe 'multi' do

    it 'should allow a player to craft in quantity' do
      add_inventory(@one, @copper_ore.code, 10)
      add_inventory(@one, @zinc_ore.code, 5)

      command! @one, :craft, [@brass.code, 5]

      @one.inv.quantity(@copper_ore.code).should == 5
      @one.inv.quantity(@zinc_ore.code).should == 0
      @one.inv.quantity(@brass.code).should == 10
      Message.receive_one(@o_sock, only: :inventory).should_not be_blank
    end

    it 'should not allow items to be crafted in quantity if player has too few ingredients' do
      add_inventory(@one, @copper_ore.code, 10)
      add_inventory(@one, @zinc_ore.code, 3)

      command(@one, :craft, [@brass.code, 5]).errors.should_not eq []

      @one.inv.quantity(@copper_ore.code).should == 10
      @one.inv.quantity(@zinc_ore.code).should == 3
      @one.inv.quantity(@brass.code).should == 0
    end
  end

  describe 'skill levels' do

    before(:each) do
      @sign = Game.item('signs/copper-small')

      add_inventory(@one, @copper.code, 40)
      add_inventory(@one, @pitch.code, 40)
    end

    it 'should not allow a player to craft something over their skill limit' do
      cmd = command(@one, :craft, [@sign.code])
      cmd.errors.size.should eq 1
      cmd.errors.to_s.should =~ /skilled/

      @one.inv.quantity(@copper.code).should eq 40
      @one.inv.quantity(@pitch.code).should eq 40
      @one.inv.quantity(@sign.code).should eq 0
    end

    it 'should allow a player to craft something over their skill limit if they have a boosting accessory' do
      craft_accessory = Game.item('accessories/glove')
      add_inventory(@one, craft_accessory.code, 1, 'a')

      cmd = command(@one, :craft, [@sign.code])
      cmd.errors.to_s.should =~ /skilled/

      craft_accessory['bonus']['building'] = 1
      cmd = command!(@one, :craft, [@sign.code])
      cmd.errors.to_s.should_not =~ /skilled/

      @one.inv.quantity(@copper.code).should eq 37
      @one.inv.quantity(@pitch.code).should eq 39
      @one.inv.quantity(@sign.code).should eq 1
    end

  end

  describe "helpers" do

    before(:each) do
      @helper_ingredient = stub_item("helper ingredient")
      @helper_machine = stub_item("helper machine", { "block_size" => [3,3], "crafting_helper" => true, "steam" => true, "meta" => "hidden" })
      @helper_block = stub_item("helper block", { "crafting_helper" => true, "meta" => "hidden" })
      @helper_craftable = stub_item('helper craftable', { "ingredients" => [[@helper_ingredient.id, 10]], "crafting_helpers" => [[@helper_machine.id, 2], [@helper_block.id, 1]], "crafting quantity" => 3 })

      add_inventory(@one, @helper_ingredient.code, 10)
    end

    it "should allow a player to craft items with activated helper machines and helper blocks nearby" do
      @one.zone.update_block nil, 40, 2, FRONT, @helper_machine.code, 1
      @one.zone.update_block nil, 40, 5, FRONT, @helper_machine.code, 1
      @one.zone.update_block nil, 40, 8, FRONT, @helper_block.code

      cmd = command(@one, :craft, [@helper_craftable.code])
      cmd.errors.should eq([])
      @one.inv.quantity(@helper_craftable.code).should eq 3
    end

    it "should not allow a player to craft items with deactivated helper machines that overlap other blocks" do
      @one.zone.update_block nil, 40, 2, FRONT, @helper_machine.code, 1
      @one.zone.update_block nil, 41, 2, FRONT, @helper_machine.code, 1
      @one.zone.update_block nil, 40, 8, FRONT, @helper_block.code

      cmd = command(@one, :craft, [@helper_craftable.code])
      cmd.errors.to_s.should =~ /must not overlap/
      @one.inv.quantity(@helper_craftable.code).should eq 0
    end

    it "should not allow a player to craft items with deactivated helper machines and helper blocks nearby" do
      @one.zone.update_block nil, 40, 2, FRONT, @helper_machine.code, 0
      @one.zone.update_block nil, 40, 5, FRONT, @helper_machine.code, 0
      @one.zone.update_block nil, 40, 8, FRONT, @helper_block.code

      cmd = command(@one, :craft, [@helper_craftable.code])
      cmd.errors.to_s.should =~ /Two activated helper machines/
      @one.inv.quantity(@helper_craftable.code).should eq 0
    end

    it "should not allow a player to craft items with activated helper machines and no helper blocks nearby" do
      @one.zone.update_block nil, 40, 2, FRONT, @helper_machine.code, 1
      @one.zone.update_block nil, 40, 5, FRONT, @helper_machine.code, 1

      cmd = command(@one, :craft, [@helper_craftable.code])
      cmd.errors.to_s.should =~ /A helper block/
      @one.inv.quantity(@helper_craftable.code).should eq 0
    end

  end
end
