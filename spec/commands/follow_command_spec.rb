require 'spec_helper'

describe FollowCommand do
  before(:each) do
    @zone = ZoneFoundry.create
    @zone2 = ZoneFoundry.create

    @one, @o_sock = auth_context(@zone)
    @two, @t_sock = auth_context(@zone)
    @three, @th_sock = auth_context(@zone2)
  end

  it 'should notify a player if a followee cannot be found by name' do
    name = 'Floop de doopapopolis'
    Message.new(:follow, [name, true]).send(@o_sock)
    Message.receive_one(@o_sock, only: :notification).data.first.should == "Couldn't find a player named #{name}"
  end

  it 'should let a player follow another' do
    Message.new(:follow, [@two.name, true]).send(@o_sock)

    Message.receive_one(@o_sock, only: :follow).data.first.should == [@two.name, @two.id.to_s, 0, true]
    Message.receive_one(@t_sock, only: :follow).data.first.should == [@one.name, @one.id.to_s, 1, true]

    eventually do
      @one.followees.should == [@two.id]
      @two.followers.should == [@one.id]
      @one.reload
      @two.reload
      @one.followees.should == [@two.id]
      @two.followers.should == [@one.id]
    end
  end

  it 'should let a player follow a player not on the same server' do
    Message.new(:follow, [@three.name, true]).send(@o_sock)

    Message.receive_one(@o_sock, only: :follow).data.first.should == [@three.name, @three.id.to_s, 0, true]

    eventually do
      @one.followees.should == [@three.id]
      one_id = @one.id
      Player.find_by_id(@three.id, { callbacks: false }) do |three|
        three.followers.should == [one_id]
      end
    end
  end

  # it 'should let a player unfollow another' do
  #   Message.new(:health, [6000]).send(@o_sock)

  #   reactor_wait
  #   @one.health.should eq 5.0
  # end
end