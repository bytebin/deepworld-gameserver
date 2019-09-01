require 'spec_helper'

describe :achievements, :with_a_zone_and_player do

  describe 'progress' do

    before(:each) do
      @player.progress = {
        'creatures killed' => 125,
        'minerals mined' => 50,
        'undertakings' => 10,
        'purifier parts discovered' => 2,
        'brains killed' => 950
      }
    end

    it 'should provide a summary of player achievement progress' do
      Achievements.progress_summary(@player).should eq({
        "Miner"=>0.5, "Master Miner"=>0.1, "Master Undertaker"=>0.4, "Master Hunter"=>0.25, "Grandmaster Hunter"=>0.05, "Legendary Hunter"=>0.01, "Ecologist"=>0.4, "Master Ecologist"=>0.08
      })
    end

    it 'should create an achievement progress message from achievement progress summary' do
      msg = Achievements.progress_summary_message(@player)
      msg.data.should =~ [["Ecologist", 40], ["Grandmaster Hunter", 5], ["Legendary Hunter", 1], ["Master Ecologist", 8], ["Master Hunter", 25], ["Master Miner", 10], ["Master Undertaker", 40], ["Miner", 50]]
    end

  end
end
