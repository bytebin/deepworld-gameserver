require 'spec_helper'

describe 'Chat' do
  before(:each) do
    with_a_zone

    @chatter = with_a_player
    with_2_players
  end

  it 'should broadcast message to self and other players' do
    command! @chatter, :chat, [nil, "What up g?"]
    #require 'debugger'; debugger

    receive_msg!(@chatter, :chat)
    receive_msg!(@one, :chat)
    receive_msg!(@two, :chat)
  end

  it 'should send message to requested player' do
    command! @chatter, :chat, [@one.name, "What up g?"]
    Message.receive_one(@one.socket, only: :chat).should be_message :chat
    Message.receive_one(@two.socket, only: :chat).should be_nil
  end

  it 'should not send chats across zones' do
    with_a_zone
    @three, @e_sock = auth_context(@zone)
    command! @chatter, :chat, [nil, "What up g?"]
    Message.receive_one(@e_sock, only: :chat).should be_nil
  end

  it 'should not send chats from muted players' do
    @chatter.muted = true
    command! @chatter, :chat, [nil, "What up g?"]
    Message.receive_one(@chatter.socket, only: :chat).should be_message :chat
    Message.receive_one(@one.socket, only: :chat).should be_blank
    Message.receive_one(@two.socket, only: :chat).should be_blank
  end

  it 'should deny non supported commands' do
    command! @chatter, :chat, [nil, '*dostuff one two three']

    msg = Message.receive_one(@chatter.socket, only: :notification)
    msg.should_not be_blank
    msg.data.to_s.should =~ /Unknown command/

    Message.receive_one(@chatter.socket, only: :chat).should be_blank
  end

  it 'should not send chats to others in the tutorial' do
    @zone.static = true
    @zone.static_type = 'tutorial'

    command! @chatter, :chat, [nil, "What up g?"]
    Message.receive_one(@chatter.socket, only: :chat).should_not be_nil
    Message.receive_one(@one.socket, only: :chat).should be_nil
    Message.receive_one(@two.socket, only: :chat).should be_nil
  end

  describe 'reporting' do

    it 'should support an asterisk command with a space before the command' do
      command! @chatter, :chat, [nil, "* report #{@one.name.downcase}"]
      msg = Message.receive_one(@chatter.socket, only: :dialog)
    end

    describe 'successful' do

      before(:each) do
        mute_one
      end

      def mute_one
        command! @chatter, :console, ['mute', [@one.name]]
        msg = receive_msg(@chatter, :notification)
        msg.data.to_s.should =~ /has been muted/
      end

      it 'should allow muting of players' do
        command! @chatter, :dialog, [@dialog_id, ['mute']]
        @chatter.mutings[@one.id.to_s].should eq 0

        # Check muted status
        command! @one, :chat, [nil, 'u suck']
        one_chat = Message.receive_one(@one.socket, only: :chat)
        one_chat.should_not be_blank
        one_chat.data.to_s.should =~ /u suck/
        ch_chat = Message.receive_one(@chatter.socket, only: :chat)
        ch_chat.should be_blank
      end
    end

    it 'should create flag alerts' do
      command! @chatter, :chat, [nil, 'give me ur password']
      eventually do
        flag = collection(:flag).find.first
        flag.should_not be_blank
        flag['player_id'].should eq @chatter.id
        flag['zone_id'].should eq @chatter.zone.id
        flag['created_at'].should_not be_blank
        flag['reason'].should =~ /password/
        flag['data'].should eq({ 'chat' => 'give me ur password' })
      end
    end

  end
end