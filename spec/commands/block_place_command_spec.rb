require 'spec_helper'
include BlockHelpers

describe BlockPlaceCommand do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty)

    @one, @o_sock = auth_context(@zone, {inventory: { '600' => [ 2, 'i', 1 ], '890' => [2, 'i', 1] }} )
    @two, @t_sock = auth_context(@zone)
    extend_player_reach @one, @two

    @zone = Game.zones[@zone.id]
    Game.play
  end

  it 'should prevent me from placing if I have too little inventory' do
    cmd = BlockPlaceCommand.new([1, 1, FRONT, 512, 0], @one.connection)
    cmd.execute!
    cmd.errors.to_s.should =~ /doesn't have any/
  end

  it 'should send block changes to players when I place' do
    # Make sure two is "active" in the chunk for updates
    Message.new(:blocks_request, [[0]]).send(@t_sock)
    Message.new(:block_place, [1, 2, 1, 600, 0]).send(@o_sock)

    eventually { @zone.peek(1, 2, 1).should eq [600, 0] }
    msg = receive_msg!(@two, :block_change)
    msg.data.should eq [[1, 2, 1, 1, 600, 0]]
  end

  it 'should decrement my inventory when I place a block' do
    initial_count = @one.inv.quantity(600)
    Message.new(:block_place, [1, 2, 1, 600, 0]).send(@o_sock)
    Message.receive_one(@o_sock)

    eventually { @one.inv.quantity(600).should eq initial_count - 1 }
  end

  describe 'adjacent changes' do

    before(:each) do
      @item = stub_item('item1', { 'adjacent_change' => [[0, 1], '!', 'adjacentable', 'item2', 3] })
      @change_item = stub_item('item2')
      @adjacentable_item = stub_item('item3', { 'use' => { 'adjacentable' => true } })
      @non_adjacentable_item = stub_item('item4')

      add_inventory(@one, @item.code, 100)
    end

    it 'should not transform a block if placed next to the proper block' do
      @zone.update_block nil, 0, 1, FRONT, @adjacentable_item.code
      command! @one, :block_place, [0, 0, FRONT, @item.code, 0]
      @zone.peek(0, 0, FRONT)[0].should eq @item.code
      @zone.process_block_timers true
      @zone.peek(0, 0, FRONT)[0].should eq @item.code
    end

    it 'should transform a block if not placed next to the proper block' do
      @zone.update_block nil, 0, 1, FRONT, @non_adjacentable_item.code
      command! @one, :block_place, [0, 0, FRONT, @item.code, 0]
      @zone.peek(0, 0, FRONT)[0].should eq @item.code
      @zone.process_block_timers true
      @zone.peek(0, 0, FRONT)[0].should eq @change_item.code
    end

  end

  describe 'additional costs' do

    before(:each) do
      @fuel = Game.item_code('accessories/battery')
      @butler = Game.item_code('mechanical/butler-brass')
      add_inventory(@one, @butler)
      @one.skills['automata'] = 3
    end

    it 'should decrement additional "cost" inventory when I place a block' do
      add_inventory(@one, @fuel)
      command! @one, :block_place, [1, 1, FRONT, @butler, 0]
      @one.inv.quantity(@fuel).should eq 0
    end

    it 'should not let me place if I do not have cost inventory' do
      command(@one, :block_place, [1, 1, FRONT, @butler, 0]).errors.to_s.should =~ /cost/
    end

  end

  it 'should not let me place blocks closer than their minimum spacing' do
    @plaque = 914
    Game.item(@plaque).spacing = 10
    Game.item(@plaque).meta = 'global'

    add_inventory(@one, @plaque, 3)
    too_close_block = @zone.peek(5, 1, FRONT)

    place(1, 1, @plaque)
    Message.receive_one(@o_sock, only: :notification).should be_nil
    place(5, 1, @plaque)
    Message.receive_one(@o_sock, only: :notification).try(:data).to_s.should =~ /10 blocks/
    @zone.peek(5, 1, FRONT).should == too_close_block
    @zone.meta_blocks.size.should == 1

    place(11, 1, @plaque)
    Message.receive_one(@o_sock, only: :notification).should be_nil
    @zone.peek(11, 1, FRONT)[0].should == @plaque
    @zone.meta_blocks.size.should == 2
  end

  it 'should not let me place near spawns' do
    spawn_item = stub_item('spawn', { 'meta' => 'global', 'use' => { 'zone teleport' => true } } )
    other_item = stub_item('item', { 'spawn_spacing' => 10 })

    add_inventory(@one, other_item.code, 10)
    @zone.update_block nil, 1, 1, FRONT, spawn_item.code

    command(@one, :block_place, [5, 5, FRONT, other_item.code, 0]).errors.to_s.should =~ /spawn/
    command! @one, :block_place, [11, 11, FRONT, other_item.code, 0]
  end

  it 'should not let me place in front of spawn in my own world' do
    @zone.owners = [@one.id]

    spawn_item = stub_item('spawn', { 'meta' => 'global', 'use' => { 'zone teleport' => true }, 'block_size' => [3,3]} )
    item = 601 # wood board

    add_inventory(@one, item, 10)
    @zone.update_block nil, 5, 5, FRONT, spawn_item.code

    command(@one, :block_place, [6, 4, FRONT, item, 0]).errors.to_s.should =~ /Cannot place over spawn/
    command! @one, :block_place, [1, 1, FRONT, item, 0]
  end

  it 'should track inventory changes for trackable blocks' do
    item = Game.item_code('ground/onyx')
    add_inventory(@one, item, 3)
    @zone.update_block nil, 2, 2, FRONT, 0

    Game.clear_inventory_changes
    place(2, 2, item)
    Game.write_inventory_changes

    eventually do
      collection(:inventory_changes).count.should eq 1
      inv = collection(:inventory_changes).find.first
      inv.should_not be_blank
      inv['p'].should eq @one.id
      inv['z'].should eq @zone.id
      inv['i'].should eq item
      inv['q'].should eq -1
      inv['tq'].should eq 2
      inv['l'].should eq [2, 2]
      inv['op'].should be_blank
      inv['oi'].should be_blank
      inv['oq'].should be_blank
    end
  end

  describe 'ownership items' do

    before(:each) do
      @ownership_item = Game.item_code('mechanical/zone-teleporter')
      add_inventory(@one, @ownership_item, 1)
    end

    it 'should allow players to place ownership items in worlds they own' do
      @zone.owners = [@one.id]
      command! @one, :block_place, [1, 1, 2, @ownership_item, 0]
    end

    it 'should prevent players from placing ownership items in worlds they do not own' do
      command(@one, :block_place, [1, 1, 2, @ownership_item, 0]).errors.to_s.should =~ /own/
    end

  end

  it 'should prevent low karma players from placing' do
    @one.suppressed = true
    wood = Game.item_code('building/wood')
    add_inventory(@one, wood)

    cmd = command(@one, :block_place, [3, 3, 2, wood, 0])
    cmd.errors.count.should eq 1
    cmd.errors.first.should match /karma is too low/
  end

  describe 'static zone' do
    before(:each) do
      @zone.static = true
    end

    it 'should decrement my inventory when I place a block' do
      initial_count = @one.inv.quantity(600)
      Message.new(:block_place, [1, 2, 1, 600, 0]).send(@o_sock)
      Message.receive_one(@o_sock)

      eventually { @one.inv.quantity(600).should eq initial_count - 1 }
    end

    it 'should not change the world or send changes to players' do
      # Make sure two is "active" in the chunk for updates
      Message.new(:blocks_request, [[0]]).send(@t_sock)
      Message.new(:block_place, [1, 2, 1, 600, 0]).send(@o_sock)
      sleep 0.125

      eventually { @zone.peek(1, 2, 1).should eq [0, 0] }
      Message.receive_one(@t_sock, only: :block_change).should be_nil
    end
  end

  describe 'meta blocks' do

    before(:each) do
      Message.new(:block_place, [1, 2, FRONT, 890, 0]).send(@o_sock)
    end

    it 'should send out meta info to me when I place a meta item' do
      Message.receive_one(@o_sock, only: :block_meta).data.first.should == [1, 2, {'i' => 890, 'p' => @one.id.to_s }]
    end

    it 'should send out meta info to other players when I place a meta item' do
      Message.receive_one(@t_sock, only: :block_meta).data.first.should == [1, 2, {'i' => 890, 'p' => @one.id.to_s }]
    end

    it 'should send meta info when I join' do
      @three, @e_sock, initial_messages = auth_context(@zone)
      meta = initial_messages.find{ |m| m.is_a?(BlockMetaMessage) }
      meta.should_not be_blank
      meta.data.first.should == [1, 2, {'i' => 890, 'p' => @one.id.to_s }]
    end
  end

  describe 'force field protected items' do

    before(:each) do
      @dish = 854 # Protective dish
      @item = 601 # 1x1 item (wood)

      add_inventory(@two, @dish, 2)
      add_inventory(@one, @dish, 2)
      add_inventory(@one, @item, 1)

      Game.item(@dish).field = 5 # Protection radius of 5
      @zone.update_block nil, 15, 10, FRONT
      @zone.update_block nil, 15, 11, FRONT

      @zone.meta_blocks.size.should == 0
    end

    it "should not let me place within protected blocks" do
      place(15, 10, @dish, @two).errors.should == []
      place(15, 11, @item, @one).errors.first.should match /protected area/
    end

    it "should not let me place within protected blocks if they're privately protected by my followees" do
      @two.follow @one
      place(15, 10, @dish, @two).errors.should == []
      place(15, 11, @item, @one).errors.first.should match /protected area/
    end

    it "should let me place within protected blocks if they're 'followee' protected by my followees" do
      @two.follow @one
      place(15, 10, @dish, @two).errors.should == []
      command! @two, :block_use, [15, 10, FRONT, [1]]

      place(15, 11, @item, @one).errors.should eq []
    end

    it "should not let me place a dish that will overlap fields with an existing dish" do
      @zone.update_block nil, 15, 11, FRONT, nil

      place(1, 1, @dish, @one).errors.should == []

      # Roughly 10.6 blocks
      place(8, 9, @dish, @two).errors.should == []

      # Roughly 8.5 blocks away
      place(7, 7, @dish, @two).errors.first.should match /overlap an existing/
      @two.inv.quantity(@dish).should eq 1
    end

    it "should let me place a dish that will overlap with my own dish" do
      @zone.update_block nil, 15, 11, FRONT, nil

      place(1, 1, @dish, @one).errors.should eq []

      # Roughly 8.5 blocks away
      place(7, 7, @dish, @one).errors.should eq []
    end

    describe 'fielded devices near spawn' do

      before(:each) do
        tp = stub_item('zone teleporter', { 'meta' => 'global', 'use' => { 'zone teleport' => true } })
        @zone.update_block nil, 10, 10, FRONT, tp.code
        @item = stub_item('field', 'field' => 5)
        add_inventory @one, @item.code
      end

      it 'should not let me place a fielded device within x blocks of spawn if world is not very explored' do
        @zone.stub(:percent_explored).and_return(0.1)
        place(1, 1, @item.code, @one).errors.to_s.should =~ /explored/
      end

      it 'should let me place a fielded device within x blocks of spawn if world is explored' do
        @zone.stub(:percent_explored).and_return(0.7)
        place(1, 1, @item.code, @one).errors.should eq []
      end

    end
  end

  describe 'protected worlds' do

    before(:each) do
      @zone.protection_level = 10
      @zone.owners = [@one.id]
      @zone.members = [@two.id]
      @one.owned_zones = @zone.id
      @two.member_zones = @zone.id

      @brass = Game.item_code('building/brass')
      @zone.update_block nil, 5, 5, FRONT, 0
    end

    it 'should allow owners to mine' do
      add_inventory_and_place(@one).should be_valid
    end

    it 'should allow members to mine' do
      add_inventory_and_place(@two).should be_valid
    end

    it 'should prevent non-members from mining' do
      @three, @o_sock = auth_context(@zone)
      add_inventory_and_place(@three).errors.to_s.should =~ /protected/
    end

  end

  describe 'based on player level' do

    before(:each) do
      @zone.protection_level = 2

      @brass = Game.item_code('building/brass')
      @zone.update_block nil, 5, 5, FRONT, 0
    end

    it 'should allow leveled & experienced players to place' do
      @one.level = 20
      @one.play_time = 2.days
      add_inventory_and_place(@one).should be_valid
    end

    it 'should not allow non-leveled players to place' do
      @one.skills['luck'] = 7
      @one.play_time = 4.days
      add_inventory_and_place(@one).should_not be_valid
    end

    it 'should not allow non-experienced players to place' do
      @one.skills['luck'] = 10
      @one.skills['agility'] = 10
      @one.play_time = 20.hours
      add_inventory_and_place(@one).should_not be_valid
    end

    it 'should allow non-experienced players to place if they are an owner/member' do
      @one.skills['luck'] = 10
      @one.skills['agility'] = 10
      @one.play_time = 20.hours
      @zone.owners = [@one.id]
      @zone.members = [@two.id]
      add_inventory_and_place(@one).should be_valid
      @zone.update_block nil, 5, 5, FRONT, 0
      add_inventory_and_place(@two).should be_valid
    end

  end

  def add_inventory_and_place(player)
    extend_player_reach player
    player.inv.add(@brass, 1)
    command player, :block_place, [5, 5, FRONT, @brass, 0]
  end

  describe 'switches' do

    it 'should link a mechanical door if placed right after a switch' do
      @door = Game.item_code('mechanical/door')
      @switch = Game.item_code('mechanical/switch')
      add_inventory(@one, @door, 2)
      add_inventory(@one, @switch, 2)

      place(1, 1, @switch, @one)
      @zone.get_meta_block(1, 1).data['>'].should be_nil

      place(2, 1, @door, @one)
      @zone.get_meta_block(1, 1).data['>'].should eq [[2, 1]]
    end

  end

  describe 'transmitters' do

    before(:each) do
      @teleporter = Game.item_code('mechanical/teleporter-mini')
      @beacon = Game.item_code('mechanical/beacon')
      Game.item('mechanical/teleporter-mini')['placing skill'] = nil
      Game.item('mechanical/beacon')['placing skill'] = nil
      add_inventory(@one, @teleporter, 2)
      add_inventory(@one, @beacon, 2)

      place(1, 1, @teleporter, @one)
      @zone.get_meta_block(1, 1).data['>'].should be_nil
    end

    it 'should link a transmitter to a beacon' do
      place(2, 1, @beacon, @one)
      @zone.peek(1, 1, FRONT)[1].should eq 1
      @zone.get_meta_block(1, 1).data['>'].should eq [2, 1]
    end

    it 'should not allow me to place the beacon too far away' do
      place(15, 15, @beacon, @one)
      @zone.peek(1, 1, FRONT)[1].should eq 0
      @zone.get_meta_block(1, 1).data['>'].should be_nil
      Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /transmit/
    end

    it 'should allow me to place the beacon far away if I have a high engineering level' do
      @one.skills['engineering'] = 5
      place(15, 15, @beacon, @one)
      @zone.peek(1, 1, FRONT)[1].should eq 1
      @zone.get_meta_block(1, 1).data['>'].should eq [15, 15]
    end

  end

end