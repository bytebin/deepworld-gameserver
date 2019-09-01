require 'spec_helper'

describe HeartbeatCommand do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
  end

  it 'should return a heartbeat if sent one' do
    Message.new(:heartbeat, [0, 0]).send(@o_sock)
    msg = Message.receive_one(@o_sock, only: :heartbeat)

    msg.should_not be_blank
    msg = Message.receive_one(@o_sock, only: :heartbeat)
    msg.should be_blank
  end

  it 'should update the last_activity_at of the zone' do
    previous_activity = @zone.last_activity_at
    time_travel(5.minutes)
    Message.new(:heartbeat, [0, 0]).send(@o_sock)
    msg = Message.receive_one(@o_sock, only: :heartbeat)

    @zone = reload_zone(@zone)
    (@zone.last_activity_at - previous_activity).should >= 5.minutes
  end
end
