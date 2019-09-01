require 'spec_helper'

describe FollowMessage do
  # before(:each) do
  #   @zone = ZoneFoundry.create

  #   @one, @o_sock = auth_context(@zone)
  #   @two, @t_sock = auth_context(@zone)
  # end

  # it 'should send a player their followees at connection' do


  #   Message.new(:follow, [name, true]).send(@o_sock)
  #   Message.receive_one(@o_sock, only: :notification).data.first.should == "Can't find player #{name}"
  # end

  # it 'should let a player follow another' do
  #   Message.new(:follow, [@two.name, true]).send(@o_sock)

  #   Message.receive_one(@o_sock, only: :follow).data.first.should == [@two.name, 0, true]
  #   Message.receive_one(@t_sock, only: :follow).data.first.should == [@one.name, 1, true]

  #   eventually do
  #     @one.followees.should == [@two.id]
  #     @two.followers.should == [@one.id]
  #     @one.reload
  #     @two.reload
  #     @one.followees.should == [@two.id]
  #     @two.followers.should == [@one.id]
  #   end
  # end

  # it 'should let a player unfollow another' do
  #   Message.new(:health, [6000]).send(@o_sock)

  #   reactor_wait
  #   @one.health.should eq 5.0
  # end
end