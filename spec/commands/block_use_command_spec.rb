require 'spec_helper'
require 'yaml'
include BlockHelpers

describe BlockUseCommand do
  before(:each) do
    @dish = 854 # Protective dish

    @zone = ZoneFoundry.create(data_path: :twentyempty)


    @protected_item = stub_item('protected', meta: 'local', use: { protected: true, dialog:
      { target: 'meta', sections:
        YAML.load(%{
          - title: Text
            input:
              type: text
              max: 10
              key: 't'
          - title: Color
            input:
              type: color
              options: ['222638', '6d4f40', 'c5b485', 'b09d42', '465c40', '4b393f']
              key: 't*'
          - title: Style
            input:
              type: select
              options: ['signs/small-1', 'signs/small-2', 'signs/small-3', 'signs/small-4']
              mod: true
        }).to_a
    }})

    @one, @o_sock = auth_context(@zone, inventory: { '610' => [ 99, 'i', 1 ], '773' => [ 99, 'i', 2 ], @protected_item.code.to_s => [ 99, 'i', 3 ], @dish.to_s => [ 1, 'i', 4 ] })
    @two, @t_sock = auth_context(@zone)
    extend_player_reach @one, @two

    @zone = Game.zones[@zone.id]

    Game.play
  end

  pending 'should update changeable items' do
    Message.new(:block_place, [1, 2, 1, 610, 0]).send(@o_sock)
  end

  describe 'protectors & protected blocks' do

    it 'should allow a player to update the type of protection on a dish' do
      place(10, 10, @dish, @one)
      @zone.meta_blocks.values.first.data['t'].should == nil
      command! @one, :block_use, [10, 10, FRONT, [1]]
      @zone.meta_blocks.values.first.data['t'].should == 1
    end

    it 'should not allow followees to update protection type' do
      place(10, 10, @dish, @one)
      @two.followers << @one.id
      command!(@two, :block_use, [10, 10, FRONT, [1]]).should be_public
      @zone.meta_blocks.values.first.data['t'].should_not == 1
    end

    it 'should not allow other players to use protected items that are not theirs' do
      Message.new(:block_place, [1, 2, FRONT, @protected_item.code, 0]).send(@o_sock)
      Message.new(:block_use, [1, 2, FRONT, ['text', 0, 0]]).send(@t_sock)
      Message.receive_one(@t_sock, only: :notification).data.first.should =~ /somebody else/
    end

    pending 'should allow players to use protected items of their followees' do
      place(10, 10, @dish, @one)
      place(11, 11, @protected_item.code, @one)

      command(@two, :block_use, [11, 11, FRONT, ['text', 0, 0]]).errors.should_not eq []
      @two.followers << @one.id
      command! @two, :block_use, [11, 11, FRONT, ['text', 0, 0]]
    end


  end



  # ===== CONTAINERS ===== #

  describe 'containers' do

    before(:each) do
      @chest_code = Game.item('containers/chest').code
      @zone.update_block nil, 2, 2, FRONT, @chest_code
      @zone.set_meta_block 2, 2, @chest_code, nil
      @chest_meta = @zone.get_meta_block(2, 2)
    end

    describe 'keys and locks' do

      before(:each) do
        @chest_meta.data['k'] = 3
      end

      it 'should let me open a locked container if I have the key' do
        @one.keys = [1, 3, 5, 10]
        cmd = BlockUseCommand.new([2, 2, FRONT, nil], @one.connection)
        cmd.execute!
        cmd.errors.should == []

        @chest_meta.should_not be_locked
        Message.receive_one(@o_sock, only: :notification).should be_nil
      end

      it 'should not let me open a locked container if I do not have the key' do
        @one.keys = [1, 5, 10]
        cmd = BlockUseCommand.new([2, 2, FRONT, nil], @one.connection)
        cmd.execute!
        cmd.errors.should_not == []
        cmd.errors.first.should =~ /lock/

        Message.receive_one(@o_sock, only: :notification).data.first.should =~ /unlock/
      end

    end

    describe 'geck' do

      before(:each) do
        @geck_item_code = Game.item('mechanical/geck-hoses').code
        @chest_meta.data['$'] = @geck_item_code
      end

      it 'should claim a GECK piece if I use a chest with one in it' do
        Message.new(:block_use, [2, 2, FRONT, nil]).send(@o_sock)

        msgs = Message.receive_one(@o_sock, only: :notification)
        msgs.data.first.to_s.should =~ /you discovered/i
        msgs.data.last.should == 10

        tmsg = Message.receive_one(@t_sock, only: :notification)
        tmsg.data.first.should =~ /#{@one.name} discovered/i
        tmsg.data.last.should == 11

        @zone.get_meta_block(2, 2).should_not be_special_item
        @zone.machine_parts_discovered(:geck).should include(@geck_item_code)
      end
    end

    describe 'loot' do

      before(:each) do
        @chest_meta.data['$'] = '?'
      end

      it 'should give me loot' do
        cmd = command!(@one, :block_use, [2, 2, FRONT, nil])
        msg = Message.receive_one(@o_sock, only: :notification)
        msg.data.to_s.should =~ /You found/
      end

      it 'should give me protected loot only if protectors are disabled' do
        protector_item = stub_item('item')
        @zone.update_block nil, 10, 10, FRONT, protector_item.code
        @zone.update_block nil, 11, 11, FRONT, protector_item.code
        @chest_meta.data['prot'] = [[10, 10, protector_item.code], [11, 11, protector_item.code]]

        command! @one, :block_use, [2, 2, FRONT, nil]
        Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /secure/

        @zone.update_block nil, 10, 10, FRONT, 0
        command! @one, :block_use, [2, 2, FRONT, nil]
        Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /secure/

        @zone.update_block nil, 11, 11, FRONT, 0
        command! @one, :block_use, [2, 2, FRONT, nil]
        Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /You found/
      end

    end

  end



  # ===== TELEPORTERS ===== #

  describe 'teleporters' do

    before(:each) do
      @teleporter_code = Game.item_code('mechanical/teleporter')
    end

    it 'should repair an inactive teleporter' do
      @zone.update_block nil, 1, 2, FRONT, @teleporter_code
      @zone.set_meta_block 1, 2, nil

      cmd = BlockUseCommand.new([1, 2, FRONT, nil], @one.connection)
      cmd.execute!
      cmd.errors.should be_blank

      msgs = Message.receive_one(@o_sock, only: :notification)
      msgs.data.first.to_s.should =~ /you repaired/i
      msgs.data.last.should == 10

      tmsg = Message.receive_one(@t_sock, only: :notification)
      tmsg.data.first.should =~ /#{@one.name} repaired/i
      tmsg.data.last.should == 11

      meta = @zone.get_meta_block(1, 2)
      meta.should_not be_blank
      meta.item.code.should == @teleporter_code
    end

  end



  # ===== DIALOGS ===== #

  describe 'dialog items' do

    before(:each) do
      Message.new(:block_place, [1, 2, FRONT, @protected_item.code, 0]).send(@o_sock)
      reactor_wait
    end

    it 'should error on dialog updates with an improper number of arguments' do
      cmd = BlockUseCommand.new([1, 2, FRONT, ['text']], @one.connection)
      cmd.execute!
      cmd.errors.first.should =~ /arguments/
    end

    it 'should error if dialog text is above the maximum required size' do
      cmd = BlockUseCommand.new([1, 2, FRONT, ['texty text mctexterson texter textlessly texting', 0, 0]], @one.connection)
      cmd.execute!
      cmd.errors.first.should =~ /max/
    end

    it 'should error if dialog text is not text' do
      cmd = BlockUseCommand.new([1, 2, FRONT, [1234, '222638', 'signs/small-1']], @one.connection)
      cmd.execute!
      cmd.errors.first.should =~ /text/
    end

    it 'should error if dialog option is not within range' do
      cmd = BlockUseCommand.new([1, 2, FRONT, ['text', '123456', 'signs/small-1']], @one.connection)
      cmd.execute!
      cmd.errors.first.should =~ /options/
    end

    it 'should allow dialog items to be updated and send out metadata' do
      cmd = BlockUseCommand.new([1, 2, FRONT, ['text', '222638', 'signs/small-1']], @one.connection)
      cmd.execute!
      cmd.errors.should == []

      hash = Message.receive_many(@o_sock, only: :block_meta).last.data.first.last
      hash['i'].should == @protected_item.code
      hash['p'].should == @one.id.to_s
      hash['t'].should == 'text'
      hash['t*'].should == '222638'
    end

    it 'should send updated dialog items to new players' do
      cmd = BlockUseCommand.new([1, 2, FRONT, ['text', '222638', 'signs/small-1']], @one.connection)
      cmd.execute!
      cmd.errors.should == []

      # Shouldn't be in initial messages since it's local
      @three, @e_sock, initial_messages = auth_context(@zone)
      meta = initial_messages.find{ |m| m.is_a?(BlockMetaMessage) }
      meta.should be_blank

      BlocksRequestCommand.new([[0]], @one.connection).execute!
      eventually do
        meta = Message.receive_one(@o_sock, only: :block_meta)
        meta.should_not be_blank
        hash = meta.data.first[2]
        hash['i'].should == @protected_item.code
        hash['p'].should == @one.id.to_s
        hash['t'].should == 'text'
        hash['t*'].should == '222638'
      end

    end

    it 'should create a chest of plenty with static items' do
      @one.admin = true
      chest = Game.item_code('containers/chest-plenty')
      add_inventory(@one, chest)
      command! @one, :block_place, [5, 5, FRONT, chest, 0]
      command! @one, :block_use, [5, 5, FRONT, ['tools/pickaxe', '5', '']]
      @zone.peek(5, 5, FRONT)[0].should eq chest
      meta = @zone.get_meta_block(5, 5)
      meta.data['y'].should > 0
      meta.data['cd'].should eq true
      meta.data['l'].should eq 'tools/pickaxe'
      meta.data['q'].should eq '5'
      meta.should be_special_item
    end

  end

  describe 'switches' do

    it 'should switch linked doors' do
      @zone.update_block nil, 10, 10, FRONT, Game.item_code('mechanical/switch'), 0 # Will be switched on
      @zone.update_block nil, 11, 10, FRONT, Game.item_code('mechanical/door'), 0 # Will be opened
      @zone.update_block nil, 12, 10, FRONT, Game.item_code('mechanical/door'), 0 # Will be opened
      @zone.update_block nil, 13, 10, FRONT, Game.item_code('mechanical/door'), 0 # Won't be opened
      @zone.update_block nil, 14, 10, FRONT, Game.item_code('mechanical/switch'), 0 # Won't be switched on

      @zone.set_meta_block 10, 10, Game.item('mechanical/switch'), nil, { '>' => [[11, 10], [12, 10]] }

      command! @one, :block_use, [10, 10, FRONT, []]

      @zone.peek(10, 10, FRONT).should eq [Game.item_code('mechanical/switch'), 1] # Switch should be on
      @zone.peek(11, 10, FRONT)[1].should eq 1 # Door should be open
      @zone.peek(12, 10, FRONT)[1].should eq 1 # Door should be open
      @zone.peek(13, 10, FRONT)[1].should eq 0 # Door should not be open
      @zone.peek(14, 10, FRONT)[1].should eq 0 # Switch should not be on

      command! @one, :block_use, [10, 10, FRONT, []]

      @zone.peek(10, 10, FRONT)[1].should eq 0 # Switch should be off again
      @zone.peek(11, 10, FRONT)[1].should eq 0 # Door should be closed again
      @zone.peek(12, 10, FRONT)[1].should eq 0 # Door should be closed again
      @zone.peek(13, 10, FRONT)[1].should eq 0 # Door should still not be open
      @zone.peek(14, 10, FRONT)[1].should eq 0 # Switch should still not be on

    end

  end

  describe 'claimables' do

    it 'should let a player claim a claimable item' do
      item = stub_item('item', 'meta' => 'global', 'use' => { 'claimable' => true })
      @zone.update_block nil, 5, 5, FRONT, item.code
      command! @one, :block_use, [5, 5, FRONT, []]
      @zone.get_meta_block(5, 5).player_id.should eq @one.id.to_s
      Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /claimed/

      command! @two, :block_use, [5, 5, FRONT, []]
      @zone.get_meta_block(5, 5).player_id.should eq @one.id.to_s
      Message.receive_one(@t_sock, only: :notification).data.to_s.should =~ /owned by/
    end

    it 'should not let a player claim more than x claimable items per zone if specified' do
      item = stub_item('item', 'meta' => 'global', 'use' => { 'claimable' => true, 'claimable_zone_limit' => 1 })
      @zone.update_block nil, 5, 5, FRONT, item.code
      @zone.update_block nil, 6, 6, FRONT, item.code

      command! @one, :block_use, [5, 5, FRONT, []]
      Message.receive_one(@o_sock, only: :notification).should_not be_blank

      command! @one, :block_use, [6, 6, FRONT, []]
      @zone.get_meta_block(6, 6).player_id.should be_blank
      Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /only/
    end

  end

end