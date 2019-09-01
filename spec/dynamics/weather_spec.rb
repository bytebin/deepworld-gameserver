require 'spec_helper'

describe Dynamics::Weather do

  describe 'arctic' do

    before(:each) do
      with_a_zone biome: 'arctic'
      with_a_player
      extend_player_reach @one
    end

    describe 'with a freeze duration' do

      before(:each) do
        @freeze_duration = 60.seconds
        @one.stub(:freeze_period).and_return(@freeze_duration)
      end

      it 'should send freeze message when I join' do
        msg = @one.setup_messages.find{ |m| m.is_a?(StatMessage) }
        msg.data.should eq [['freeze', 0]]
      end

      it 'should unfreeze me if I die' do
        @one.freeze = 0.5
        @one.die!
        @one.freeze.should eq 0
      end

      it 'should not unfreeze me if I try to warm myself on a pending fire' do
        @one.freeze = 0.5
        @fireplace = Game.item_code('furniture/fireplace')
        @zone.update_block nil, 2, 2, FRONT, @fireplace, 0

        command! @one, :block_use, [2, 2, FRONT, nil]
        @one.freeze.should eq 0.5
      end

      it 'should unfreeze me if I warm myself' do
        @one.freeze = 0.5
        @fireplace = Game.item_code('furniture/fireplace')
        @zone.update_block nil, 2, 2, FRONT, @fireplace, 1

        command! @one, :block_use, [2, 2, FRONT, nil]
        @one.freeze.should eq 0
      end

      it 'should damage me if I freeze long enough' do
        @one.freeze = 0
        @zone.weather.cold.step 60.seconds
        @one.freeze.should eq 1.0
        @zone.weather.cold.step 1.1
        @one.health.should < 5.0
      end

    end

    it 'should have a longer freeze period for higher survivaled players' do
      @one.skills['survival'] = 1
      short_period = @one.freeze_period
      @one.skills['survival'] = 2
      long_period = @one.freeze_period

      short_period.should < long_period
    end

  end

  describe 'thirst' do

    describe 'desert' do

      before(:each) do
        with_a_zone biome: 'desert'
        @water = Game.item_code('containers/jar-water')
      end

      it 'should increase thirst in a desert biome' do
        with_a_player
        step!
        @one.thirst.should > 0
      end

      it 'should not increase thirst if player has high survival' do
        with_a_player @zone, skills: { 'survival' => 8 }
        step!
        @one.thirst.should eq 0
      end

      it 'should subtract water from inventory to reset thirst' do
        with_a_player @zone
        @one.inv.add @water, 1
        @one.thirst = 1.0
        step!
        @one.inv.contains?(@water).should be_false
        @one.thirst.should eq 0
      end

      it 'should damage a player without water' do
        with_a_player @zone
        start_health = @one.health
        @one.thirst = 1.0
        step!
        @one.thirst.should eq 1.0
        @one.health.should < start_health
      end

      it 'should not apply thirst in a "purified" desert world' do
        with_a_player @zone
        @zone.acidity = 0
        @one.thirsts?.should be_false
      end

    end

    it 'should decrease thirst in a non-desert biome' do
      with_a_zone biome: 'plain'
      with_a_player @zone, thirst: 0.5
      step!
      @one.thirst.should < 0.5
    end

  end

  def step!
    @zone.weather.step! 1.0
  end

end