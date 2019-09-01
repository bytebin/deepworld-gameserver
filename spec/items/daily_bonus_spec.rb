require 'spec_helper'

describe Items::DailyBonus do

  before(:each) do
    with_a_zone
    with_a_player @zone
  end

  def use!(ref = '123', bump_play_time = 1.hour)
    @one.play_time += bump_play_time
    Items::DailyBonus.new(@one).use!(ref: ref)
  end

  it 'should reward me' do
    use!
    receive_msg!(@one, :inventory)
    receive_msg!(@one, :notification).data.to_s.should =~ /sure/i
  end

  it 'should increase my multiplier if I go to the same source' do
    use!
    @one.daily_bonus['mult'].should eq 1
    time_travel 1.day
    use!
    @one.daily_bonus['mult'].should eq 2
  end

  it 'should reset my multiplier if I go to a different source' do
    use!
    @one.daily_bonus['mult'].should eq 1
    use! '456'
    @one.daily_bonus['mult'].should eq 1
  end

  describe 'timing' do

    it 'should increase my multiplier if I return the next day, adjusted by time zone' do
      @one.time_zone = '+06:00'
      stub_date Time.new(2013, 1, 31, 12, 0, 0, '+00:00') # UTC - Jan 31st at noon, +6 - Jan 31st at 6 PM
      use!
      stub_date Time.new(2013, 1, 31, 20, 0, 0, '+00:00') # UTC - Jan 31st at 8 PM, +6 - Feb 1st at 2 AM
      use!
      @one.daily_bonus['mult'].should eq 2
    end

    it 'should increase my multiplier if I return the next day and it is a new year, adjusted by time zone' do
      @one.time_zone = '+10:00'
      stub_date Time.new(2013, 12, 31, 12, 0, 0, '+00:00') # UTC - Dec 31st at noon, +10 - Dec 31st at 10 PM
      use!
      stub_date Time.new(2013, 12, 31, 16, 0, 0, '+00:00') # UTC - Dec 31st at 4 PM, +10 - Jan 1st at 2 AM
      use!
      @one.daily_bonus['mult'].should eq 2
    end

    it 'should reset my multiplier if I do not return the next day, adjusted by time zone' do
      stub_date Time.new(2013, 1, 31, 12, 0, 0, '+00:00') # UTC - Jan 31st at noon
      use!
      stub_date Time.new(2013, 2, 2, 12, 0, 0, '+00:00') # UTC - Feb 2nd at noon
      use!
      @one.daily_bonus['mult'].should eq 1
    end

    it 'should notify me I cannot get another bonus yet if it is not the next day' do
      @one.time_zone = '-02:00'
      stub_date Time.new(2013, 1, 31, 12, 0, 0, '+00:00') # UTC - Jan 31st at noon, -2 - Jan 31st at 10 AM
      use!
      stub_date Time.new(2013, 1, 31, 20, 0, 0, '+00:00') # UTC - Jan 31st at 8 PM, -2 - Jan 31st at 6 PM
      use!
      @one.daily_bonus['mult'].should eq 1
      receive_msg!(@one, :dialog).data.to_s.should =~ /come back tomorrow/i
    end

  end

  describe 'play time' do

    it 'should not reward me if I have not played enough since my last reward' do
      use! '123', 0
      time_travel 24.hours
      use! '123', 5.minutes
      @one.daily_bonus['mult'].should eq 1
      receive_msg!(@one, :dialog).data.to_s.should =~ /yet/
    end

  end

end