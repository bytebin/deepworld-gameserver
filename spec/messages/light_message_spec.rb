require 'spec_helper'

describe LightMessage do
  before(:each) do
    @zone = ZoneFoundry.create
  end

  it 'should send me a message with sunlight when I request chunks' do
    @one, @o_sock, @o_messages, @setup_messages = auth_context(@zone)
    
    Message.new(:blocks_request, [[0]]).send(@o_sock)
    Game.step!
    reactor_wait
    message = Message.receive_one(@o_sock, only: :light)

    message.should_not be_nil
    message[:x].first.should == 0
    message[:y].first.should == 0
    message[:type].first.should == 0
    message[:value].first[0..12].should == [2, 2, 2, 3, 3, 3, 3, 6, 6, 6, 6, 6, 3]
  end

  it 'should send a message when a block is mined and clears a path for sunlight' do
    @one, @o_sock, @o_messages, @setup_messages = auth_context(@zone)
    # TODO
  end

end