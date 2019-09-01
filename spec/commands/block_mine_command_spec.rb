require 'spec_helper'
include BlockHelpers

describe BlockMineCommand do
  before(:each) do
    @dish = stub_item('dish', { 'meta' => 'local', 'mod' => 'field', 'field' => 5, 'use' =>
      { 'protected' => true, 'dialog' => { 'target' => 'meta', 'sections' => [{ 'input' => { 'type' => 'text index', 'options' => ['me', 'others'], 'key' => 't' }}]}}}).code
    @broken_dish = 856 # Broken dish

    @zone = ZoneFoundry.create(data_path: :bunker, liquid_enabled: false)
    @one, @o_sock = auth_context(@zone, inventory: { @dish.to_s => 2 } )
    @two, @t_sock = auth_context(@zone, inventory: { @dish.to_s => 2, @broken_dish.to_s => 2 } )
    extend_player_reach @one, @two

    @one.active_indexes = [0]
    @two.active_indexes = [0]

    @zone = Game.zones[@zone.id]
  end

  it 'should send single block change to players when I mine' do
    @one.command!(BlockMineCommand, [1, 2, 2, item1 = @zone.peek(1,2,FRONT)[0], 0]).errors.should be_empty

    @zone.send_block_changes

    message = Message.receive_one(@t_sock, only: [:block_change])

    message.should be_message(:block_change)
    message[:entity_id].should eq [@one.entity_id]
    message[:x].should eq [1]
    message[:y].should eq [2]
    message[:layer].should eq [2]
    message[:item_id].should eq [0]
  end

  it 'should send multiple block changes to players when I mine' do
    @one.command!(BlockMineCommand, [1, 2, 2, item1 = @zone.peek(1,2,FRONT)[0], 0]).errors.should be_empty
    @one.command!(BlockMineCommand, [6, 6, 2, item1 = @zone.peek(1,6,FRONT)[0], 0]).errors.should be_empty

    @zone.send_block_changes

    message = Message.receive_one(@t_sock, only: [:block_change])

    message.should be_message(:block_change)
    message[:entity_id].should eq [@one.entity_id] * 2
    message[:x].should eq [1,6]
    message[:y].should eq [2,6]
    message[:layer].should eq [2,2]
    message[:item_id].should eq [0, 0]
  end

  it 'should reject a mine request with the wrong item' do
    command @one, :block_mine, [1, 2, 2, 622, 0]
    message = Message.receive_one(@t_sock, ignore: [:entity_status, :entity_position])
    Message.receive_one(@t_sock, ignore: [:entity_status, :entity_position]).should be_nil
  end

  it 'should reject a mine request with an entity-based item (e.g., a turret), as the entity needs to be destroyed instead' do
    item = Game.item_code('mechanical/turret-pistol')
    @zone.update_block nil, 2, 2, FRONT, item
    mine(2, 2, item).errors.to_s.should =~ /entity/
  end

  it 'should reject a mine request with the wrong location' do
    Message.new(:block_mine, [21, 6, 1, 0, 0]).send(@o_sock)
    Message.receive_one(@t_sock, ignore: [:entity_status, :entity_position]).should be_nil
  end

  it 'should increment my inventory when I mine a block' do
    @zone.update_block nil, 3, 3, FRONT, Game.item_code('building/wood')
    item = @zone.peek(3,3, FRONT)[0]
    initial_count = @one.inv.quantity(item)

    Message.new(:block_mine, [3, 3, 2, item, 0]).send(@o_sock)
    Message.receive_one(@o_sock)

    reactor_wait
    @one.inv.quantity(item).should eq initial_count + 1
  end

  describe 'alternate inventory' do

    it "should increment alternate inventory when a block's item has different inventory specified" do
      resin = 539
      item = @zone.peek(1,3,FRONT)[0]
      item.should_not == resin # We're counting on different items in the zone
      initial_count = @one.inv.quantity(resin)

      Message.new(:block_mine, [1, 3, 2, item, 0]).send(@o_sock)
      Message.receive_one(@o_sock)

      reactor_wait
      @one.inv.quantity(resin).should eq initial_count + 1
    end

    it 'should add inventory only at a mod level' do
      item1 = stub_item('item1', { 'inventory' => '', 'mod_inventory' => [2, 'item2'] })
      item2 = stub_item('item2')

      @zone.update_block nil, 2, 2, FRONT, item1.code
      command! @one, :block_mine, [2, 2, FRONT, item1.code, 0]
      @one.inv.quantity(item1.code).should eq 0
      @one.inv.quantity(item2.code).should eq 0

      @zone.update_block nil, 2, 2, FRONT, item1.code, 1
      command! @one, :block_mine, [2, 2, FRONT, item1.code, 0]
      @one.inv.quantity(item1.code).should eq 0
      @one.inv.quantity(item2.code).should eq 0

      @zone.update_block nil, 2, 2, FRONT, item1.code, 2
      command! @one, :block_mine, [2, 2, FRONT, item1.code, 0]
      @one.inv.quantity(item1.code).should eq 0
      @one.inv.quantity(item2.code).should eq 1
    end

  end

  it 'should track inventory changes for trackable blocks' do
    item = Game.item_code('ground/onyx')
    @zone.update_block nil, 2, 2, FRONT, item

    Game.clear_inventory_changes
    mine!(2, 2, item)
    Game.write_inventory_changes

    eventually do
      inv = collection(:inventory_changes).find.first
      inv.should_not be_blank
      inv['p'].should eq @one.id
      inv['z'].should eq @zone.id
      inv['i'].should eq item
      inv['q'].should eq 1
      inv['l'].should eq [2, 2]
      inv['op'].should be_blank
      inv['oi'].should be_blank
      inv['oq'].should be_blank
    end
  end

  it 'should not track inventory changes for untrackable blocks' do
    item = Game.item_code('ground/earth')
    @zone.update_block nil, 2, 2, FRONT, item
    mine(2, 2, item)
    Game.write_inventory_changes

    inv = collection(:inventory_changes).find.first
    inv.should be_blank
  end

  it 'should not let me mine the last world teleporter' do
    item = Game.item_code('mechanical/zone-teleporter')
    @zone.meta_blocks_with_item(item).size.should eq 0
    @zone.update_block @one.entity_id, 2, 2, FRONT, item
    command @one, :block_mine, [2, 2, FRONT, item, 0]
    Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /at least one/
  end

  describe 'skill requirements' do

    before(:each) do
      @skill_item = Game.item_code('ground/earth-deep')
      @zone.update_block nil, 2, 2, FRONT, @skill_item
    end

    it 'should allow me to mine a skill-required block if my skill is high enough' do
      @one.skills['mining'] = 3
      mine(2, 2, @skill_item).errors.should == []
    end

    it 'should not allow me to mine a skill-required block if my skill is too low' do
      @one.skills['mining'] = 2
      mine(2, 2, @skill_item).errors.to_s.should =~ /skill/
    end

  end

  describe 'decay' do

    before(:each) do
      @wood = Game.item_code('rubble/wood-1')
      @wood_board = Game.item_code('building/wood-board')
      @one.inv.add(@wood.to_s)
      @one.inv.add(@wood_board.to_s)
    end

    it 'should increment ingredient inventory when a block is decayed' do
      @zone.update_block nil, 1, 3, FRONT, @wood_board, 3

      Message.new(:block_mine, [1, 3, FRONT, @wood_board, 0]).send(@o_sock)

      eventually {
        @one.inv.quantity(@wood).should == 2
        @one.inv.quantity(@wood_board).should == 1
      }
    end

    it 'should not increment ingredient inventory when a decayable block is not decayed' do
      @zone.update_block nil, 1, 3, FRONT, @wood_board, 0

      Message.new(:block_mine, [1, 3, FRONT, @wood_board, 0]).send(@o_sock)

      eventually {
        @one.inv.quantity(@wood).should == 1
        @one.inv.quantity(@wood_board).should == 2
      }
    end

  end

  describe 'containers' do

    before(:each) do
      @chest_code = Game.item('containers/chest').code
      @geck_item_code = Game.item('mechanical/geck-hoses').code
      @zone.update_block nil, 2, 2, FRONT, @chest_code
      @zone.set_meta_block 2, 2, @chest_code, nil, { '$' => @geck_item_code }
    end

    it 'should not let me mine a container with a special item in it' do
      mine(2, 2, @chest_code).errors.to_s.should =~ /special item/
    end

    it 'should not let me mine a locked container' do
      @zone.get_meta_block(2, 2).data['k'] = 10
      mine(2, 2, @chest_code).errors.to_s.should =~ /locked/
    end

  end

  describe 'invulnerable items' do

    before(:each) do
      @item = 935 # Checkpoint
      @zone.update_block nil, 2, 2, FRONT, @item
    end

    it 'should not let me mine invulnerable items' do
      mine(2, 2, @item).errors.to_s.should =~ /invulnerable/
    end

    it 'should let me mine invulnerable items as an admin' do
      @one.admin = true
      mine(2, 2, @item).errors.should_not be_blank
      @one.admin_enabled = true
      mine(2, 2, @item).errors.should be_blank
    end

  end

  describe 'force field protected items' do

    before(:each) do
      Game.item(@dish).field = 5 # Proection radius of 5
      @item = 601 # 1x1 item (wood)
      @zone.update_block nil, 10, 10, FRONT, 0
      @zone.update_block nil, 15, 10, FRONT, @item # Inside radius
      @zone.update_block nil, 15, 11, FRONT, @item # Outside radius
      @zone.meta_blocks.size.should == 0
    end

    it "should not let me mine strangers' protected blocks" do
      place(10, 10, @dish, @two).errors.should == []
      mine(15, 11, @item).errors.should == []
      mine(15, 10, @item).errors.to_s.should =~ /protected/
      mine(10, 10, @dish).errors.to_s.should =~ /protected/
    end

    it "should let me mine strangers' protected blocks if they're not 'fieldable' items" do
      place(10, 10, @broken_dish, @two).errors.should == []

      @one.skills['engineering'] = 10
      mine(10, 10, @broken_dish).errors.should == []
    end

    it "should let me mine my followers' protected blocks if the protector is set to do so" do
      @one.followers << @two.id
      place(10, 10, @dish, @two).errors.should == []
      command! @two, :block_use, [10, 10, FRONT, [1]]

      @zone.get_meta_block(10, 10)['t'].should eq 1
      mine(15, 10, @item).errors.should eq []
    end

    it "should not let me mine my followers' protected blocks if the protector is not set to do so" do
      @one.followers << @two.id
      place(10, 10, @dish, @two).errors.should eq []

      mine(15, 10, @item).errors.should_not eq []
    end

    it "should not let me mine my followers' *protectors*" do
      @one.followers << @two.id
      place(10, 10, @dish, @two).errors.should == []

      mine(10, 10, @dish).errors.should_not == []
    end

    it "should not let me mine my followers' *protectors* even if set to allow followers access" do
      place(10, 10, @dish, @two).errors.should == []
      command! @two, :block_use, [10, 10, FRONT, [1]]

      @one.followers << @two.id
      mine(10, 10, @dish).errors.should_not == []
    end

    it "should let me mine my own protected blocks" do
      place(10, 10, @dish, @one).errors.should == []
      mine(15, 11, @item).errors.should == []
      mine(15, 10, @item).errors.should == []
      mine(10, 10, @dish).errors.should == []
    end

    it "should let me mine any protected blocks if I'm an active admin" do
      place(10, 10, @dish, @two).errors.should == []
      @one.admin = true
      mine(15, 10, @item).errors.should_not eq []
      @one.admin_enabled = true
      mine(15, 10, @item).errors.should eq []
      mine(10, 10, @dish).errors.should eq []
    end

    describe 'field 1 items' do

      before(:each) do
        @item = stub_item('item', { 'meta' => 'local', 'field' => 1 })
        @zone.update_block nil, 1, 1, FRONT, @item.code
      end

      it 'should let me mine adjacent to a field 1 item' do
        other_item = stub_item('other_item')
        @zone.update_block nil, 0, 1, FRONT, other_item.code
        mine(0, 1, other_item.code).errors.should eq []
      end

      it 'should not let me mine a field 1 item' do
        mine(1, 1, @item.code).errors.should_not eq []
      end

    end

    describe 'field coverage items' do

      before(:each) do
        @item = stub_item('item', { 'meta' => 'local', 'field' => 1, 'field_coverage' => [3, 3] })
        @other_item = stub_item('other_item')
        @zone.update_block nil, 3, 3, FRONT, @item.code
      end

      it 'should let me mine blocks outside a field coverage' do
        @zone.update_block nil, 6, 2, FRONT, @other_item.code
        mine(6, 2, @other_item.code).errors.should eq []
      end

      it 'should not let me mine blocks inside a field coverage' do
        @zone.update_block nil, 5, 2, FRONT, @other_item.code
        mine(5, 2, @other_item.code).errors.to_s.should =~ /protected/
      end

    end

  end

  describe 'protected globally' do

    before(:each) do
      @zone.protection_level = 10
      @zone.owners = [@one.id]
      @zone.members = [@two.id]
      @one.owned_zones = @zone.id
      @two.member_zones = @zone.id

      brass = Game.item_code('building/brass')
      @zone.update_block nil, 5, 5, FRONT, brass
      @args = [5, 5, FRONT, brass, 0]
    end

    it 'should allow owners to mine' do
      command! @one, :block_mine, @args
    end

    it 'should allow members to mine' do
      command! @two, :block_mine, @args
    end

    it 'should prevent non-members from mining' do
      @three, @o_sock = auth_context(@zone)
      extend_player_reach @three
      command(@three, :block_mine, @args).errors.to_s.should =~ /protected/
      command(@three, :block_mine, @args).should_not be_valid
    end
  end

  describe 'based on player level' do

    before(:each) do
      @zone.protection_level = 1
      brass = Game.item_code('building/brass')
      @zone.update_block nil, 5, 5, FRONT, brass
      @args = [5, 5, FRONT, brass, 0]
    end

    it 'should allow leveled & experienced players to mine' do
      @one.level = 20
      @one.play_time = 1.day
      command! @one, :block_mine, @args
    end

    it 'should not allow non-leveled players to mine' do
      @one.level = 2
      @one.play_time = 1.day
      command(@one, :block_mine, @args).should_not be_valid
    end

    it 'should not allow non-experienced players to mine' do
      @one.level = 20
      @one.play_time = 23.hours
      command(@one, :block_mine, @args).should_not be_valid
    end

  end

  describe 'digging' do

    before(:each) do
      @zone.update_block nil, 5, 5, FRONT, 512
      @one.current_item = Game.item_code('tools/shovel')
      @dug = Game.item_code('ground/earth-dug')
    end

    it 'should let me dig earth with a shovel' do
      command! @one, :block_mine, [5, 5, FRONT, 512, 0]
      @zone.peek(5, 5, FRONT).should eq [@dug, 0]
      @zone.process_dig_queue Time.now + 10.seconds
      @zone.peek(5, 5, FRONT).should eq [512, 0]
    end

    it 'should let me dig protected earth with a shovel' do
      @zone.update_block nil, 6, 6, FRONT, Game.item_code('mechanical/protector-enemy')
      command! @one, :block_mine, [5, 5, FRONT, 512, 0]
      @zone.peek(5, 5, FRONT).should eq [@dug, 0]
    end

    it 'should restore modded items when dug' do
      compost = Game.item_code('ground/earth-compost')
      @zone.update_block nil, 5, 5, FRONT, compost, 3
      command! @one, :block_mine, [5, 5, FRONT, compost, 0]
      @zone.process_dig_queue Time.now + 10.seconds
      @zone.peek(5, 5, FRONT).should eq [compost, 3]
    end

    it 'should not restore a dug block if the dug earth is mined first' do
      command! @one, :block_mine, [5, 5, FRONT, 512, 0]
      command! @one, :block_mine, [5, 5, FRONT, @dug, 0]
      @zone.process_dig_queue Time.now + 10.seconds
      @zone.peek(5, 5, FRONT).should eq [0, 0]
    end

  end

  describe 'switches' do

    before(:each) do
      @switch = stub_item('switch', { 'use' => { 'switch' => true }, 'meta' => 'hidden' })
      @door = stub_item('door', { 'use' => { 'switched' => true }})

      @zone.update_block nil, 5, 5, FRONT, @switch.code
      @zone.update_block nil, 6, 6, FRONT, @door.code
      @meta = @zone.get_meta_block(5, 5)
      @meta.data['>'] = [[6, 6]]
    end

    it 'should not let a player mine an anonymous switch if the door still exists' do
      command(@one, :block_mine, [5, 5, FRONT, @switch.code, 0]).errors.to_s.should =~ /switch/
    end

    it 'should let a player mine a player-placed switch if the door still exists' do
      @meta.player_id = @one.id.to_s
      command! @one, :block_mine, [5, 5, FRONT, @switch.code, 0]
    end

  end

  it 'should prevent low karma players from mining' do
    @one.suppressed = true
    @zone.update_block nil, 3, 3, FRONT, Game.item_code('building/wood')

    cmd = BlockMineCommand.new([3, 3, 2, Game.item_code('building/wood'), 0], @one.connection)
    cmd.execute!
    cmd.errors.count.should eq 1
    cmd.errors.first.should match /karma is too low/
  end

  describe 'adjacent mining' do

    it 'should auto-mine adjacent blocks' do
      item_1 = stub_item('item1', { 'group' => 'stuff' })
      adj_item_1 = stub_item('item2', { 'adjacent_mine' => [[0, -1], 'stuff'] })
      @zone.update_block nil, 1, 0, FRONT, item_1.code
      @zone.update_block nil, 1, 1, FRONT, adj_item_1.code
      command! @one, :block_mine, [1, 1, FRONT, adj_item_1.code, 0]
      @zone.peek(1, 0, FRONT).should eq [0, 0]
      @one.inv.contains?(item_1.code).should be_true
    end

    it 'should auto-mine adjacent blocks with modded inventory' do
      item_1 = stub_item('item1', { 'group' => 'stuff' })
      item_2 = stub_item('item2', { 'inventory' => '', 'mod_inventory' => [3, 'item1']})
      adj_item_1 = stub_item('item3', { 'adjacent_mine' => [[0, -1], 'stuff'] })
      @zone.update_block nil, 1, 0, FRONT, item_1.code, 3
      @zone.update_block nil, 1, 1, FRONT, adj_item_1.code
      command! @one, :block_mine, [1, 1, FRONT, adj_item_1.code, 0]
      @zone.peek(1, 0, FRONT).should eq [0, 0]
      @one.inv.contains?(item_1.code).should be_true
      @one.inv.contains?(item_2.code).should be_false
    end

  end

end
