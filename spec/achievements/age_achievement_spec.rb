require 'spec_helper'

describe Achievements::AgeAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @one.play_time = 333
    @zone = Game.zones[@zone.id]
  end

  it 'should award me with an alpha user award if my player is old enough' do
    @two, @t_sock, initial_messages = auth_context(@zone, created_at: Time.utc(2012, 4, 15), play_time: 2.hours.to_i)
    msg = Message.receive_one(@t_sock, only: :achievement)
    msg.should_not be_blank
    msg.data.first.should == ['Alpha Tester', 2000]
  end

  it 'should not award me with a beta user award if my player is an alpha user' do
    @two, @t_sock = auth_context(@zone, created_at: Time.utc(2012, 4, 15), play_time: 2.hours.to_i)
    msgs = Message.receive_many(@t_sock, only: :achievement)
    msgs.each do |msg|
      msg.data.each do |ach|
        ach.first.should_not == 'beta'
      end
    end
  end

  it 'should award me with an beta user award if my player is old enough' do
    @two, @t_sock = auth_context(@zone, created_at: Time.utc(2012, 5, 15), play_time: 2.hours.to_i)
    msg = Message.receive_one(@t_sock, only: :achievement)
    msg.should_not be_blank
    msg.data.first.should == ['Beta Tester', 2000]
  end

end
