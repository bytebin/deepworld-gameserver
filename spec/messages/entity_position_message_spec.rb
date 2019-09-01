require 'spec_helper'

describe EntityPositionMessage do
  context 'with a zone and and 2 players' do
    before(:each) do
      with_a_zone
      with_2_players(@zone)
    end

    it "should send me another players position" do
      @one.position = Vector2[5.5, 5.5]
      command!(@one, :move, [5 * Entity::POS_MULTIPLIER, 5 * Entity::POS_MULTIPLIER, 2, 2, 1, 0, 0, 1]).should be_valid

      eventually do
        msg = Message.receive_one(@one.socket, only: :entity_position)
        msg[:entity_id].should eq [@two.entity_id]

        msg = Message.receive_one(@two.socket, only: :entity_position)
        msg[:entity_id].should eq [@one.entity_id]
      end
    end
  end

  context 'with a tutorial zone and 2 players' do
    before(:each) do
      with_a_zone(static: true, static_type: 'tutorial')
      with_2_players(@zone)
    end

    it "should not send me another players position" do
      receive_msg(@one, :entity_position).should be_nil

      @one.position = Vector2[5.5, 5.5]
      command!(@one, :move, [5 * Entity::POS_MULTIPLIER, 5 * Entity::POS_MULTIPLIER, 2, 2, 1, 0, 0, 1]).should be_valid

      receive_msg(@one, :entity_position).should be_nil
    end
  end
end