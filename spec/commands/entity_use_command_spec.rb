require 'spec_helper'
include EntityHelpers
include DialogHelpers

describe EntityUseCommand do
  before(:each) do
    with_a_zone
    with_a_player(@zone)
  end

  it 'should not splode' do
    Message.new(:entity_use, [0, 0]).send(@one.socket)
  end

  describe 'trading' do

    before(:each) do
      @zone.stub(:can_trade?).and_return(true)

      add_inventory(@one, 512, 50)

      @two = register_player(@zone)
      add_inventory(@two, 650, 50)

      stub_epoch_ids @one, @two
    end

    def trade_item(originator, recipient, item_code)
      command! originator, :entity_use, [recipient.entity_id, ['trade', item_code]]
    end

    describe 'giving' do

      def give(giver, taker, item_code, amt)
        trade_item giver, taker, item_code
        dialog_id, sections = receive_dialog(giver.socket)
        sections[0]['title'].should =~ /Trade/
        sections[1]['input']['type'].should eq 'text select'
        sections[1]['input']['options'].should eq %w{1 2 3 4 5 6 7 8 9 10 15 20 25 30 40 50} if amt <= 50

        command! giver, :dialog, [dialog_id, [amt.to_s, 'Give freely']]
      end

      it 'should not allow a player to give something they do not have' do
        dish = stub_item('dish').code
        trade_item @one, @two, dish
        msg = Message.receive_one(@one.socket, only: :notification)
        msg.data.to_s.should =~ /enough/
        @one.inv.quantity(dish).should eq 0
        @two.inv.quantity(dish).should eq 0
      end

      it 'should allow a player to give to another player' do
        give @one, @two, 512, 5

        @one.inv.quantity(512).should eq 45
        @two.inv.quantity(512).should eq 5

        @one.trade.should be_nil
        @two.trade.should be_nil
      end

      it 'should award an earthbombing achievement for giving 1000 earth to xx players' do
        Game.config.achievements['Earthbomber'].quantity = 3
        add_inventory(@one, 512, 3000)

        @three = register_player(@zone)
        @four = register_player(@zone)

        stub_epoch_ids @one, @two, @three, @four
        give @one, @two, 512, 1000
        give @one, @three, 512, 1000
        @one.achievements.keys.should_not include('Earthbomber')
        give @one, @four, 512, 1000
        @one.achievements.keys.should include('Earthbomber')
      end

    end

    describe 'trading' do

      it 'should not allow me to initiate trades with untradeable items' do
        # Player 1 drags jetpack to player 2
        trade_item @one, @two, Game.item_code('accessories/jetpack')

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should_not be_blank
        msg.data.to_s.should =~ /Cannot/

        @one.trade.should be_nil
        @two.trade.should be_nil
      end

      it 'should not allow me to respond to trades with untradeable items' do
        dialog_id = start_trade
        respond_to_trade @one, @two, dialog_id, Game.item_code('accessories/jetpack')

        msg = Message.receive_one(@two.socket, only: :notification)
        msg.should_not be_blank
        msg.data.to_s.should =~ /Cannot/
      end

      def initiate_trade(quantity)
        # Player 1 drags earth to player 2
        trade_item @one, @two, 512

        # Player 1 gets offer quantity dialog
        dialog_id, sections = receive_dialog(@one.socket)

        # Player 1 sets offer quantity to 5 and requests trade
        command! @one, :dialog, [dialog_id, [quantity.to_s, 'Request trade']]

        dialog_id
      end

      def start_trade
        dialog_id = initiate_trade(5)

        # Player 1 gets notification that their request was sent
        receive_dialog(@one.socket).to_s.should =~ /sent/

        # Player 2 receives dialog asking if they want to trade
        dialog_id, sections = receive_dialog(@two.socket)

        dialog_id
      end

      def respond_to_trade(one, two, dialog_id, item_code)
        # Player 2 accepts trade
        command! two, :dialog, [dialog_id, []]

        # Player 2 gets instructions to drag item to player 1
        receive_dialog(two.socket).to_s.should =~ /drag/i

        # Player 1 gets dialog saying that player 2 accepted
        receive_dialog(one.socket).to_s.should =~ /accepted/

        # Player 2 drags brass to player 1
        trade_item two, one, item_code
      end

      def complete_trade(one, two, dialog_id)
        respond_to_trade one, two, dialog_id, 650

        # Player 2 gets counteroffer quantity dialog
        dialog_id, sections = receive_dialog(two.socket)

        # Player 2 sets counteroffer quantity
        command! two, :dialog, [dialog_id, ['2']]

        # Player 2 gets notification that their counteroffer was sent
        receive_dialog(two.socket).to_s.should =~ /offer/

        # Player 1 gets confirmation dialog
        dialog_id, sections = receive_dialog(one.socket)

        # Player 1 confirms trade
        command! one, :dialog, [dialog_id, []]
      end

      it 'should allow a player to trade with another player' do
        Game.clear_inventory_changes

        dialog_id = start_trade
        complete_trade @one, @two, dialog_id

        # Inventories are updated
        @one.inv.quantity(512).should eq 45
        @one.inv.quantity(650).should eq 2
        @two.inv.quantity(512).should eq 5
        @two.inv.quantity(650).should eq 48

        # Trade is cleared
        @one.trade.should be_nil
        @two.trade.should be_nil

        # Inventory changes are tracked
        Game.write_inventory_changes
        eventually do
          inv = collection(:inventory_changes).find('$or' => [{p: @one.id}, {p: @two.id}]).to_a
          inv.count.should eq 2

          inv.first['p'].should eq @one.id
          inv.first['z'].should eq @zone.id
          inv.first['i'].should eq 512
          inv.first['q'].should eq -5
          inv.first['tq'].should eq 45
          inv.first['l'].should be_nil
          inv.first['op'].should eq @two.id
          inv.first['oi'].should eq 650
          inv.first['oq'].should eq 2
        end
      end

      it 'should allow a player to explicitly cancel a trade' do
        dialog_id = start_trade

        # Player 2 declines trade
        command! @two, :dialog, [dialog_id, ['cancel']]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should_not be_blank
        msg.data.to_s.should =~ /#{@two.name} cancelled/

        msg = Message.receive_one(@two.socket, only: :notification)
        msg.should_not be_blank
        msg.data.to_s.should =~ /You cancelled/

        # Trade is cleared
        @one.trade.should be_nil
        @two.trade.should be_nil
      end

      def full_trade
        add_inventory(@one, 512, 5000)
        add_inventory(@two, 650, 50)

        dialog_id = start_trade
        complete_trade @one, @two, dialog_id

        # Clear out messages
        Message.receive_one(@one.socket, only: :dialog)
        Message.receive_one(@two.socket, only: :dialog)
      end

      it 'should award a merchant achievement for trading with xx players' do
        Game.config.achievements['Merchant'].quantity = 3
        full_trade
        @two.stub(:epoch_id).and_return(1)
        full_trade
        @one.achievements.keys.should_not include('Merchant')
        @two.stub(:epoch_id).and_return(2)
        full_trade
        @one.achievements.keys.should include('Merchant')
      end

      it 'should not award a merchant achievement for trading with the same player xx times' do
        Game.config.achievements['Merchant'].quantity = 3
        full_trade
        full_trade
        full_trade
        @one.achievements.keys.should_not include('Merchant')
      end

    end
  end
end