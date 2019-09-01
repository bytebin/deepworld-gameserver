require 'spec_helper'

describe PrivateMessageCommand do
  before(:each) do
    @zone1 = ZoneFoundry.create
    @one, @socket = auth_context(@zone1)
    @zone1 = Game.zones[@zone1.id]

    @zone2 = ZoneFoundry.create
    @two, @socket = auth_context(@zone2)
    @zone2 = Game.zones[@zone2.id]

    Game.play
  end

  def authorize_messaging!
    @two.update followees: [@one.id]
  end

  it 'should send an event message if no params are sent' do
    command! @one, :private_message, []
    msg = receive_msg!(@one, :event)
    msg.data.should eq ['pm', '']
  end

  it 'should send an event message with recipient if only recipient param is sent' do
    command! @one, :private_message, ['floopdedoop']
    msg = receive_msg!(@one, :event)
    msg.data.should eq ['pm', 'floopdedoop']
  end

  it 'should send a private message across zones' do
    authorize_messaging!
    date = Time.now
    stub_date date
    command! @one, :private_message, [@two.name, 'what is up brosky?']

    eventually do
      @zone2.last_missive_check_at = date - 1.minute
      @zone2.get_missives
      msg = receive_msg!(@two, :missive)
      msg.data[0][1..-1].should eq ["pm", date.to_i, @one.name, "what is up brosky?", false]
    end
  end

  it 'should only send the latest messages' do
    Missive.create(player_id: @one.id, created_at: Time.now - 1.day, message: 'one')
    Missive.create(player_id: @one.id, created_at: Time.now, message: 'two')
    missive_check_time = Time.now - 12.hours
    @zone1.last_missive_check_at = missive_check_time

    @zone1.get_missives
    msg = receive_msg!(@one, :missive)
    msg.data.size.should eq 1
    msg.data[0].to_s.should =~ /two/

    @zone1.last_missive_check_at.should > missive_check_time
  end

  it 'should not let me message people who do not follow me' do
    command @one, :private_message, [@two.name, 'what is up brosky?']
    receive_msg!(@one, :notification).data.to_s.should =~ /follow/
  end

  it 'should send accurate messages' do
    authorize_messaging!
    command! @one, :console, ["pm", ["#{@two.name}", "what", "is", "up", "brosky?"]]
    eventually do
      collection(:missive).find.to_a.first['message'].should eq 'what is up brosky?'
    end
  end

end