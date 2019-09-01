require 'spec_helper'

describe Connection do

  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    Game.play
  end

  it 'should properly handle small packet sends' do
    request = Message.new(:chat, [nil, "Im testing packing sending. Cool huh?"])
    request.send(@o_sock, 2)

    msg = Message.receive_one(@o_sock, only: :chat)
    msg.should_not be_nil
    msg.should be_message :chat
    msg[:message].first.should eq "Im testing packing sending. Cool huh?"
  end

  it 'should properly handle medium packet sends' do
    request = Message.new(:chat, [nil, "Im testing packing sending. Cool huh?"])
    request.send(@o_sock, 5)
    reactor_wait

    msg = Message.receive_one(@o_sock, only: :chat)
    msg.should be_message :chat
    msg[:message].first.should eq "Im testing packing sending. Cool huh?"
  end

  it 'should kick players who send invalid length commands' do
    msg = 'az' * 513
    request = Message.new(:chat, [nil, msg])
    request.send(@o_sock, nil)
    Message.receive_one(@o_sock, only: :kick).should_not be_blank
    @one.connection.disconnected.should be_true
  end

  it 'should ignore commands with unknown idents' do
    request = Message.new(250, ['a', 'b', 'c'])
    request.send(@o_sock, nil)
    request = Message.new(:chat, [nil, 'chat'])
    request.send(@o_sock, nil)
  end

  describe 'throttling' do

    def chat!
      command @one, :chat, [nil, 'I can haz crystal?']
    end

    it 'should decline messages that exceed the throttle rate' do
      ChatCommand.stub(:throttle_level).and_return([2, 2.0])
      chat!.errors.should eq []
      time_travel 1.second
      chat!.errors.should eq []
      time_travel 0.5.seconds
      chat!.errors.should_not eq []

      time_travel 2.1.seconds
      chat!.errors.should eq []
    end

    it 'should notify a throttle if configured' do
      ChatCommand.stub(:throttle_level).and_return([1, 2.0, 'stop spamming chat!'])
      chat!
      chat!
      msg = Message.receive_one(@o_sock, only: :notification)
      msg.should_not be_blank
      msg.data.to_s.should =~ /stop spamming/
    end

    it 'should not throttle messages without a throttle rate' do
      ChatCommand.stub(:throttle_level).and_return(nil)
      10.times { chat!.errors.should eq [] }
    end

  end

end
