require 'spec_helper'

describe Competition do

  it 'should assign entries', :with_a_zone_and_player do
    @competition = CompetitionFoundry.create
    @zone.name = 'Nice Place [Competition]'
    @zone.competition_id = @competition.id

    @two = PlayerFoundry.create
    @three = PlayerFoundry.create

    competition_item = stub_item('competition', { 'meta' => 'local', 'use' => { 'competition' => true }})
    @zone.update_block nil, 5, 5, FRONT, competition_item.code
    @zone.update_block nil, 10, 10, FRONT, competition_item.code
    mb2 = @zone.get_meta_block(5, 5)
    mb2.player_id = @two.id.to_s
    mb3 = @zone.get_meta_block(10, 10)
    mb3.player_id = @three.id.to_s

    srand(12345)
    @zone.initialize_competition

    eventually do
      @zone.competition.should_not be_blank
      @zone.competition.last_entry.should eq 2

      eventually do
        mb2['entry'].should eq 2
        mb2['pn'].should eq @two.name
        mb3['entry'].should eq 1
        mb3['pn'].should eq @three.name
      end

      # Re-init should do nothing
      @zone.initialize_competition
      @zone.competition.last_entry.should eq 2
    end

  end
end