require 'spec_helper'
include EntityHelpers

describe 'servants' do

  before(:each) do
    with_a_zone
    with_a_player
    extend_player_reach @one

    @brass = Game.item_code('mechanical/butler-brass')
    @diamond = Game.item_code('mechanical/butler-diamond')
    @fuel = Game.item_code('accessories/battery')

    add_inventory(@one, @brass, 3)
    add_inventory(@one, @diamond, 3)
    add_inventory(@one, @fuel, 100)
  end

  def skill(sk)
    @one.skills['automata'] = sk
  end

  def place_servant(code)
    command(@one, :block_place, [5, 5, FRONT, code, 0])
  end

  def get_servant
    @zone.servants_of_player(@one).first
  end

  def get_behavior
    if servant = get_servant
      servant.behavior.children.find{ |ch| ch.is_a?(Behavior::Butler) }
    end
  end

  describe 'existence' do

    it 'should prevent me from placing any servant if my skill is too low' do
      skill 2
      place_servant(@brass).errors.should_not eq []
    end

    it 'should prevent me from placing a high-power servant if my skill is too low' do
      skill 3
      place_servant(@diamond).errors.should_not eq []
    end

    it 'should prevent me from placing more servants than my skill can handle' do
      skill 8
      place_servant(@brass).errors.should eq []
      place_servant(@brass).errors.should eq []
      place_servant(@brass).errors.should_not eq []
    end

    describe 'active quantity' do

      before(:each) do
        skill 8
        # Leave 1 brass butler
        @one.inv.remove(@brass, @one.inv.quantity(@brass) - 1)
        place_servant(@brass).errors.should eq []
      end

      it 'should prevent me from placing more servants than I have in my inventory' do
        place_servant(@brass).errors.should_not eq []
      end

      it 'should prevent me from giving a servant if it is active' do
        @two, @t_sock = auth_context(@zone)
        cmd = @one.command!(GiveCommand, [@two.name, @brass, 1])
        cmd.errors.should_not eq []
      end

      it 'should prevent me from trading a servant if it is active' do
        @two, @t_sock = auth_context(@zone)
        @one.trade_item(@two, @brass).should be_false
      end

    end

    describe 'successful' do

      before(:each) do
        skill 8
      end

      it 'should spawn a servant' do
        place_servant(@brass).errors.should eq []

        servant = get_servant
        servant.should be_servant
        servant.owner_id.should eq @one.id
        servant.position.should eq Vector2[5, 5]

        @one.servants.size.should eq 1
        @one.servants.first.ilk.should eq 152

        @one.inv.quantity(@brass).should eq 3
      end

      describe 'timing' do

        before(:each) do
          place_servant(@brass)
          @servant = get_servant
          @behavior = get_behavior
        end

        it 'should despawn a servant after a length of time' do
          @behavior.stub(:life_duration).and_return(10.minutes)
          @behavior.extend_life

          time_travel 11.minutes
          @servant.behave!

          @one.servants.should be_blank
          get_servant.should be_blank
        end

        it 'should respawn if I have sent a command recently before lifetime ends' do
          batteries = @one.inv.quantity(@fuel)
          @behavior.stub(:life_duration).and_return(10.minutes)
          @behavior.extend_life

          time_travel 9.minutes
          @behavior.react :whatever, []
          time_travel 2.minutes
          @servant.behave!

          @one.servants.should_not be_blank
          get_servant.should_not be_blank
          @one.inv.quantity(@fuel).should < batteries
        end

        it 'should not respawn if I have no fuel left' do
          @one.inv.remove @fuel, @one.inv.quantity(@fuel)

          @behavior.stub(:life_duration).and_return(10.minutes)
          @behavior.extend_life
          @behavior.react :whatever, []

          time_travel 11.minutes
          @servant.behave!

          @one.servants.should be_blank
          get_servant.should be_blank
        end

        it 'should despawn after more time if I have higher automata skill' do
          duration = @behavior.life_duration
          @one.skills['automata'] = 10
          @behavior.life_duration.should > duration
        end

        it 'should despawn after more time if I have a butler extender' do
          duration = @behavior.life_duration
          item = stub_item('item', { 'use' => { 'butler extension' => true }})
          @one.inv.add item.code
          @one.inv.move item.code, 'a', 0
          @behavior.life_duration.should > duration
        end

      end

      it 'should subtract fuel inventory when I spawn a servant' do
        place_servant(@brass)
        @one.inv.quantity(@fuel).should eq 99
        place_servant(@diamond)
        @one.inv.quantity(@fuel).should eq 98
      end

    end

  end


  describe 'interaction' do

    before(:each) do
      skill 5
      place_servant(@brass)
      @servant = get_servant
    end

    def use_servant
      command! @one, :entity_use, [@servant.entity_id, nil]
    end

    def receive_dialog
      Message.receive_one(@one.socket, only: :dialog)
    end

    it 'should not present me with a dialog if I single click' do
      use_servant
      receive_dialog.should be_blank
    end

    it 'should present me with a dialog if I double click' do
      2.times { use_servant }
      msg = receive_dialog
      dialog_id = msg.data.first
      dialog_config = msg.data.last
      dialog_config.to_s.should =~ /orders/
    end

  end

end
