require 'spec_helper'

describe EntityItemUseMessage do
  before(:each) do
    with_a_zone
  end

  it 'should send me a message with existing entities items on entry' do
    @one = register_player(@zone)
    add_inventory(@one, 1025)
    Message.new(:inventory_use, [0, 1025, 1, nil]).send(@one.socket)

    @dude, @d_sock, msgs = auth_context(@zone)
    msg = msgs.select{|m| m.ident == BaseMessage.ident_for(:entity_item_use)[0]}[0]
    msg.should_not be_nil
    msg[:entity_id].should eq [@one.entity_id]
    msg[:item_id].should eq [1025]
    msg[:status].should eq [0]
  end
end