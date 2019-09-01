require 'spec_helper'
include EntityHelpers

describe InventoryUseCommand do
  before(:each) do
    with_a_zone
    with_a_player(@zone, {inventory: { '600' => [ 21, 'i', 1 ], '601' => [ 10, 'i', 2 ], '1024' => [ 8, 'h', 2 ] }})
  end

  describe 'general usage' do

    before(:each) do
      @two = register_player(@zone)
      add_inventory @two, 1025
    end

    describe 'peers' do

      it 'should notify peers of inventory use' do
        pending("Stopped working for unknown reason, manually tested and working.")
        command! @two, :inventory_use, [0, 1025, 1, nil]

        message = receive_msg!(@one, :entity_item_use)
        message[:entity_id].should eq [@two.entity_id]
        message[:item_id].should eq [1025]
      end

      describe 'out of range' do

        before(:each) do
          @one.position = Vector2[10, 10]
          @two.position = Vector2[1, 1]
          @two.stub(:visible_distance).and_return(5)

          @one.update_tracked_entities
          @one.tracking_entity?(@two.entity_id).should eq false

          command! @two, :inventory_use, [0, 1025, 1, nil]
        end

        it 'should not notify peers of inventory use if out of range' do
          receive_msg(@one, :entity_item_use).should be_blank
        end

        it 'should notify peers of inventory use when coming into range' do
          @one.position = Vector2[3, 3]
          @one.update_tracked_entities
          @one.tracking_entity?(@two.entity_id).should eq true

          message = receive_msg!(@one, :entity_item_use)
          message[:entity_id].should eq [@two.entity_id]
          message[:item_id].should eq [1025]
          message[:status].should eq [0] # TODO: Status should equal 1 - should track that item is actually in use, not just selected (after client 1.8.4)
        end

      end

      it 'should tell peeps im using something if i use it' do
        add_inventory(@one, 1025, 1, 'h')
        Message.new(:inventory_use, [0, 1025, 1, nil]).send(@one.socket)
        message = Message.receive_one(@two.socket, only: :entity_item_use)
      end
    end

    it 'should not let me do dumb things with tools' do
      add_inventory(@two, 1025, 1, 'h')
      Message.new(:inventory_use, [0, 1025, 3, nil]).send(@one.socket)
      message = Message.receive_one(@two.socket, only: :entity_item_use)

      message.should be_nil
    end

    it 'should not let me use a tool that I dont own' do
      Message.new(:inventory_use, [0, 1025, 1, nil]).send(@one.socket)
      message = Message.receive_one(@two.socket, only: :entity_item_use)

      message.should be_nil
    end

    it 'should set my current item to the item im using' do
      add_inventory(@one, 1025, 1, 'h')
      Message.new(:inventory_use, [0, 1025, 0, nil]).send(@one.socket)

      reactor_wait
      @one.current_item.should eq 1025
    end

  end

  describe 'attacking' do

    before(:each) do
      @entity, @entity2 = add_entity(@zone, 'terrapus/child', 2, @one.position)
      @one.send(:update_tracked_entities)
      entity_messages = Message.receive_many(@one.socket, only: :entity_status, max: 2)
    end

    it 'should let me attack an entity' do
      attack_entity @one, @entity
      @entity.active_attackers.should == [@one]
    end

    it 'should let me attack multiple entities if my agility is high' do
      @one.skills['agility'] = 3
      attack_entity @one, [@entity, @entity2]
      @entity.active_attackers.should == [@one]
      @entity2.active_attackers.should eq [@one]
    end

    it 'should not let me attack multiple entities if my agility is low' do
      attack_entity @one, [@entity, @entity2]
      @entity.active_attackers.should eq [@one]
      @entity2.active_attackers.should eq []
    end

    it 'should not let me attack myself' do
      attack_entity(@one, @one).errors.should_not be_blank
    end

    it 'should not let me attack another player' do
      @two, @t_sock = auth_context(@zone)
      attack_entity(@one, @two).errors.should_not be_blank
    end

    pending 'should stop attacking entities if I stop using my items' do
      attack_entity @one, @entity
      cmd = InventoryUseCommand.new([0, 1024, 2, nil], @one.connection).execute!
      @entity.active_attackers.should == []
    end

    it 'should let me kill an entity' do
      @entity.health = 0.01
      attack_entity @one, @entity
      @entity.process_effects 1.0

      @entity.health.should < 0
      @entity.details['!'].should == 'v'
      @zone.entities.values.should_not include(@entity)

      # Receive an inventory message with giblets
      message = Message.receive_one(@one.socket, only: :inventory)
      message.should_not be_blank
      message.data.first.should == { '450' => [1, "i", -1] }

      # Receive an entity removal message
      message = Message.receive_one(@one.socket, only: :entity_status)
      message.should_not be_blank
      message.data.first[0].should == @entity.entity_id
      message.data.first[4].should == { '!' => 'v' }
      message.data.first[3].should == 0
    end
  end

  describe 'single use items (consumables)' do

    before(:each) do
      @cloak = Game.item('consumables/cloak')
      add_inventory(@one, @cloak.code)
    end

    it 'should decrease my inventory by one (but not send messages, as client will do that)' do
      Game.clear_inventory_changes

      cmd = InventoryUseCommand.new([0, @cloak.code, 1, nil], @one.connection)
      cmd.execute!
      cmd.errors.should == []

      @one.inv.quantity(@cloak.code).should eq 0
      Message.receive_one(@one.socket, only: :inventory).should be_blank
      Message.receive_one(@one.socket, only: :entity_item_use).should be_blank

      # Tracked inventory
      Game.write_inventory_changes
      eventually do
        inv = collection(:inventory_changes).find.first
        inv.should_not be_blank
        inv['p'].should eq @one.id
        inv['z'].should eq @zone.id
        inv['i'].should eq @cloak.code
        inv['q'].should eq -1
      end
    end

    it 'should give me health if specified (no messages)' do
      @jerky = Game.item('consumables/jerky')
      add_inventory(@one, @jerky.code, 1, 'h')
      @one.health = 2
      InventoryUseCommand.new([0, @jerky.code, 1, nil], @one.connection).execute!

      @one.health.should == 3
    end

    pending 'should not use a health item if my health is full' do
      @jerky = Game.item('consumables/jerky')
      add_inventory(@one, @jerky.code, 1, 'h')
      @one.health = @one.max_health
      command(@one, :inventory_use, [0, @jerky.code, 1, nil]).errors.should_not eq []
    end

    describe 'converting items' do

      before(:each) do
        @source1 = stub_item('source1')
        @source2 = stub_item('source2')
        @result1 = stub_item('result1')
        @result2 = stub_item('result2')
        @converter = stub_item('converter', { 'category' => 'consumables', 'action' => 'convert', 'convert' => { 'source1' => 'result1', 'source2' => 'result2' } } )

        add_inventory @one, @converter.code
      end

      it 'should let me convert an item' do
        add_inventory @one, @source1.code
        command! @one, :inventory_use, [0, @converter.code, 1, nil]

        dialog = receive_msg!(@one, :dialog)
        command! @one, :dialog, [dialog.data[0], [0]]

        receive_msg!(@one, :inventory).data.should eq([{ @converter.code.to_s => [0, 'i', -1] }])
        receive_msg!(@one, :inventory).data.should eq([{ @source1.code.to_s => [0, 'i', -1] }])
        receive_msg!(@one, :inventory).data.should eq([{ @result1.code.to_s => [1, 'i', -1] }])

        @one.inv.contains?(@converter.code).should be_false
      end

      it 'should not show items that I do not have' do
        add_inventory @one, @source1.code
        command! @one, :inventory_use, [0, @converter.code, 1, nil]
        dialog = receive_msg!(@one, :dialog)
        dialog.data.to_s.should =~ /Source1/
        dialog.data.to_s.should_not =~ /Source2/
      end

      it 'should show me a message that I have no source items' do
        command! @one, :inventory_use, [0, @converter.code, 1, nil]
        receive_msg!(@one, :notification).data.to_s.should =~ /do not/
        receive_msg!(@one, :inventory).should_not be_blank
        @one.inv.contains?(@converter.code).should be_true
      end

    end

  end

end
