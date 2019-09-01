require 'spec_helper'

describe Achievements::AgeAchievement do

  it 'should award architect achievements', :with_a_zone_and_player do
    @one.check_startup_achievements
    @one.achievements.should be_blank

    @one.landmark_votes = 50
    @one.check_startup_achievements
    @one.achievements.should be_blank

    @one.landmark_votes = 200
    @one.check_startup_achievements
    @one.achievements.size.should eq 1
    @one.achievements.keys.should include('Architect')

    @one.landmark_votes = 1000
    @one.check_startup_achievements
    @one.achievements.size.should eq 2
    @one.achievements.keys.should include('Master Architect')
  end

end