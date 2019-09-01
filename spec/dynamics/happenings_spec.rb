require 'spec_helper'

describe :happenings do

  before(:each) do
    with_a_zone
    with_a_player
  end

  it "should apply XP bonus happenings" do
    @one.timed_xp_multiplier.should eq 1

    Game.stub(:happenings).and_return({ 'xp_multiplier' => { 'expire_at' => Time.now + 5.seconds, 'amount' => 2.5 }})
    @one.timed_xp_multiplier.should eq 2.5

    time_travel 6.seconds
    @one.timed_xp_multiplier.should eq 1
  end

end
