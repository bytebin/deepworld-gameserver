require 'spec_helper'

describe AchievementMessage do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @one.play_time = 333
    @zone = Game.zones[@zone.id]
  end

  it 'should send XP' do
    @one.add_achievement 'awesome'
    @one.xp.should eq 2000
  end

end