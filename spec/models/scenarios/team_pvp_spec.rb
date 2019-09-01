require 'spec_helper'

describe Scenarios::TeamPvp, :pending do

  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty, scenario: 'team_pvp')
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    Game.play
  end

  it 'should assign me a team and uniform when I join' do
    @one
  end

  it 'should assign a second user the opposite team when they join' do

  end

  it 'should let a user switch teams' do

  end

  it 'should not let a user switch teams if one team is inbalanced' do

  end

end
