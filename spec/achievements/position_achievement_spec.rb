require 'spec_helper'

describe Achievements::PositionAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
  end

  it 'should award me with a spelunker achievement if I reach the bottom' do
    @one.position = Vector2.new(0, @zone.size.y - 1)
    @zone.process_achievements

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should_not be_blank
    msg.data.first.should == ['Spelunker', 1000]
  end

  it 'should not award me with a spelunker achievement if I reach the top' do
    @one.position = Vector2.new(0, 0)
    @zone.process_achievements

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should be_blank
  end

  it 'should only award one spelunker achievement' do
    @one.position = Vector2.new(0, @zone.size.y - 1)
    @zone.process_achievements
    @zone.process_achievements

    @one.xp.should eq 1000
  end
end
