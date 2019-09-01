require 'spec_helper'

describe Schedule::Manager do

  before(:each) do
    with_a_zone
    with_a_player
  end

  pending "should apply scheduled XP bonuses" do
    @one.timed_xp_multiplier.should eq 1

    Game.schedule.add type: "xp_multiplier", limit: "all", amount: 2.5, expire_at: Time.now.to_i + 5.seconds
    @one.timed_xp_multiplier.should eq 2.5

    time_travel 6.seconds
    @one.timed_xp_multiplier.should eq 1
  end

end
