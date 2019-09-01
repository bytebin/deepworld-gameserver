require 'spec_helper'

describe MuteCommand do
  describe 'With a zone and two players' do
    before(:each) do
      with_a_zone
      with_2_players(@zone)
    end

    it 'should mute a player' do
      command @two, :console, ['mute', [@one.name]]
      receive_msg!(@two, :notification).data[0].should eq "#{@one.name} has been muted."
      collection(:players).find_one(_id: @two.id)['mutings'].should eq ({@one.id.to_s => 0})
      @two.has_muted?(@one).should be_true
    end

    it 'should mute a player for a duration' do
      t = Time.now
      command @two, :console, ['mute', [@one.name, 30]]
      receive_msg!(@two, :notification).data[0].should eq "#{@one.name} has been muted for 30 minute(s)."
      collection(:players).find_one(_id: @two.id)['mutings'].should eq ({@one.id.to_s => t.to_i + 30*60})
      @two.has_muted?(@one).should be_true
    end

    it 'should allow chats after mute duration' do
      command @two, :console, ['mute', [@one.name, 30]]
      time_travel 31.minutes
      @two.has_muted?(@one).should be_false
    end

    pending 'should notify a player of muting with /mutex command' do
      command @two, :console, ['mutex', [@one.name]]
      receive_msg!(@one, :notification).data[0].should eq "#{@two.name} has muted you"
    end

  end
end
