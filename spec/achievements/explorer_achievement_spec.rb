require 'spec_helper'

describe Achievements::ExploringAchievement do
  before(:each) do
    @progress_key = 'chunks explored'
    @zone = ZoneFoundry.create(data_path: :twohundo)
    @zone.stub(:surface_max).and_return(19)
    @one, @o_sock = auth_context(@zone, position: Vector2.new(0,0))
    @one.stub(:max_speed).and_return(Vector2.new(100, 100))
  end

  it 'should not increment progress for entering an aboveground chunk' do
    move_to(1, 15)
    @one.progress[@progress_key].should be_blank
  end

  it 'should increment progress for entering the first chunk' do
    move_to(1, 21)
    @one.progress[@progress_key].should eq 1
  end

  it 'should increment progress for entering a couple chunks' do
    move_to(1, 21)
    move_to(20, 21)
    @one.progress[@progress_key].should eq 2
  end

  it 'should not reincrement progress for entering the same chunk' do
    move_to(1, 21)
    move_to(2, 21)
    @one.progress[@progress_key].should eq 1
  end

  it 'should earn an explorer achievement' do
    @one.progress[@progress_key] = 99
    move_to(1, 21)

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should_not be_nil
    msg[:key].should eq ['Explorer']
    msg[:points].should eq [2000]
  end

  it 'should earn a master explorer achievement' do
    @one.progress[@progress_key] = 499
    move_to(1, 21)

    messages = Message.receive_many(@o_sock, only: :achievement, max: 2)

    messages.count.should eq 2
    messages.last[:key].should eq ['Master Explorer']
    messages.last[:points].should eq [5000]
  end

  # helpers
  def move_to(x, y)
    command! @one, :move, [x * Entity::POS_MULTIPLIER, y * Entity::POS_MULTIPLIER, 0, 0, 0, 0, 0, 0]
  end
end