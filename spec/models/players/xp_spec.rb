require 'spec_helper'

describe Players::Xp do

  before(:each) do
    with_a_zone
    with_2_players
    @one.current_client_version = '2.0.0'

    Players::Xp.stub(:max_level).and_return(70)
    Players::Xp.stub(:reversed_levels).and_return((1..70).to_a.reverse)
    Players::Xp.stub(:xp_for_level).with(1).and_return(0)
    (2..70).each do |lv|
      Players::Xp.stub(:xp_for_level).with(lv).and_return(lv * 1000)
    end
    Players::Xp.stub(:bonus).and_return(0)
    Players::Xp.stub(:bonus).with(:achievement).and_return(1000)
    Players::Xp.stub(:bonus).with(:deliverance).and_return(50)

    Game.config.stub(:achievements).and_return Hashie::Mash.new({
      'Awesome' => { 'xp' => 2000 },
      'Super duper' => { 'xp' => 5000 },
      'Like Whoa' => { 'xp' => 10000 }
    })
  end

  it 'should use xp for >= 2.0.0' do
    @one.current_client_version = '2.0.0'
    @one.should be_use_xp
  end

  it 'should give level for xp' do
    Players::Xp.max_level.should eq 70
    Players::Xp.level_for_xp(50).should eq 1
    Players::Xp.level_for_xp(2000).should eq 2
    Players::Xp.level_for_xp(3500).should eq 3
    Players::Xp.level_for_xp(4999).should eq 4
    Players::Xp.level_for_xp(5000).should eq 5
    Players::Xp.level_for_xp(9999999).should eq 70
  end

  it 'should grant xp for an achievement' do
    @one.xp = 50
    @one.add_achievement 'Super duper'
    receive_msg!(@one, :xp).data.should eq [5000, 5050, nil]
  end

  it 'should level up' do
    @one.level = 1
    @one.xp = 1900
    @one.add_xp 50
    @one.level.should eq 1
    @one.add_xp 50
    @one.level.should eq 2
    receive_msg!(@one, :level).data.should eq [2]
  end

  it 'should bestow multiple levels / skill points if player gets enough xp to obtain multiple levels at once' do
    @one.level = 1
    @one.xp = 4000
    @one.add_xp 5

    @one.level.should eq 4
    @one.xp.should eq 4005
    @one.points.should eq 3
  end

  describe 'legacy conversions' do

    it 'should not convert players who are not version 3' do
      @one.version = 2
      @one.convert_for_xp!

      @one.version.should eq 2
      @one.xp.should eq 0
      @one.level.should eq 1
    end

    it 'should convert players' do
      @one.progress['deliverances'] = 50
      @one.achievements = { 'Awesome' => 0 }

      @one.version = 3
      @one.convert_for_xp!

      eventually do
        @one.version.should eq 4
        @one.xp.should eq 1000 + 50*50
        @one.level.should eq 3
        @one.points.should eq 1
      end
    end

    it 'should convert players and set level to a minimum of the amount of achievements' do
      @one.achievements = { 'Awesome' => 0, 'Super duper' => 0 } # min level 3

      @one.version = 3
      @one.convert_for_xp!

      eventually do
        @one.version.should eq 4
        @one.xp.should eq 3000
        @one.level.should eq 3
        @one.points.should eq 0
      end
    end

    it 'should convert players and give points for levels beyond number of achievements' do
      @one.progress['deliverances'] = 2000/50
      @one.achievements = { 'Awesome' => 0, 'Super duper' => 0 }

      @one.version = 3
      @one.convert_for_xp!

      @one.xp.should eq 4000
      @one.version.should eq 4
      @one.level.should eq 4
      @one.points.should eq 1
    end

    it 'should max players to level 70' do
      @one.progress['deliverances'] = 999999
      @one.achievements = { 'Awesome' => 0, 'Super duper' => 0 }

      @one.version = 3
      @one.convert_for_xp!

      eventually do
        @one.version.should eq 4
        @one.level.should eq 70
        @one.points.should eq 67
      end
    end

    it 'should leave current xp players in place' do
      @one.current_client_version = '2.0.5'
      @one.created_at = Time.new(2014, 9, 15)
      @one.achievements = { 'Awesome' => 0, 'Super duper' => 0 }
      @one.level = 2
      @one.xp = 2050

      @one.version = 3
      @one.convert_for_xp!

      eventually do
        @one.version.should eq 4
        @one.level.should eq 2
        @one.xp.should eq 2050
      end
    end

    describe 'achievements' do

      before(:each) do
        @one.achievements = { 'Awesome' => 0, 'Super duper' => 0, 'Like Whoa' => 0 }
      end


      it 'should add bonus achievement XP for v3 players' do
        @one.version = 3
        @one.convert_for_xp!

        @one.version.should eq 4
        @one.xp.should eq 4000

        @one.convert_for_xp!

        @one.version.should eq 5
        @one.xp.should eq 4000 + 3000+8000
      end

      it 'should add bonus achievement XP for v4 players' do
        @one.version = 4
        @one.level = 3
        @one.xp = 1234
        @one.convert_for_xp!

        @one.version.should eq 5
        @one.xp.should eq 1234 + 3000+8000
        @one.level.should eq 3
        @one.add_xp 1
        @one.level.should eq 12
      end

      it 'should not add bonus achievement XP for newer players' do
        @one.version = 5
        @one.level = 3
        @one.xp = 3456
        @one.convert_for_xp!

        @one.version.should eq 5
        @one.xp.should eq 3456
      end

    end

  end

end