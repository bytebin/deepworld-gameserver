require 'spec_helper'

describe ZoneExploredMessage do
  before(:each) do
    with_a_zone
    with_2_players(@zone, position: [0,0])
    @one.stub(:max_speed).and_return(Vector2.new(1000, 1000))
  end

  it 'should send me and another player a zone explored message when newly explored' do
    @zone.chunks_explored.uniq.should == [false]
    
    command! @one, :move, [42 * Entity::POS_MULTIPLIER, 15 * Entity::POS_MULTIPLIER, 0, 0, 0, 0, 0, 0]
    receive_msg!(@two, :zone_explored)
  end

  it 'should not send us a duplicate zone explored message' do
    @zone.chunks_explored.uniq.should == [false]
    
    command! @one, :move, [4200, 1500, 0, 0, 0, 0, 0, 0]
    receive_msg!(@two, :zone_explored)

    command! @one, :move, [4100, 1600, 0, 0, 0, 0, 0, 0]
    receive_msg(@two, :zone_explored).should be_nil
  end
end
