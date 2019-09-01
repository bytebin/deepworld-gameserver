require 'spec_helper'

describe Achievements::MiningAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]

    extend_player_reach @one
  end

  describe 'ore' do

    before(:each) do
      Game.config.achievements['Miner'].quantity = 10
    end

    def mine(ct)
      @i ||= 0
      ct.times do
        @i += 1
        item = (550..553).random.to_i
        @zone.update_block nil, @i, 0, FRONT, item
        BlockMineCommand.new([@i, 0, FRONT, item, 0], @one.connection).execute!
      end
    end

    it 'should award me with a miner achievement if I mine enough ore' do
      mine 20
      msgs = Message.receive_many(@o_sock, only: :achievement)
      msgs.size.should == 1
      msgs.first.should_not be_blank
      msgs.first.data.first.should == ['Miner', 2000]
    end

    it 'should notify me when I pass 25% threshold of mining ore' do
      mine 2
      Message.receive_one(@o_sock, only: :notification).should be_blank
      mine 1
      msg = Message.receive_one(@o_sock, only: :notification)
      msg.should_not be_blank
      msg.data.to_s.should =~ /mined 3 ore/
      msg.data.to_s.should =~ /quarter/
      msg.data.to_s.should =~ /Miner/
    end

    it 'should notify me when I pass 50% threshold of mining ore' do
      mine 5
      msg = Message.receive_many(@o_sock, only: :notification).last
      msg.should_not be_blank
      msg.data.to_s.should =~ /halfway/
    end

    it 'should notify me when I pass 50% threshold of mining ore' do
      mine 8
      msg = Message.receive_many(@o_sock, only: :notification).last
      msg.should_not be_blank
      msg.data.to_s.should =~ /almost/
    end

  end

  it 'should award me with a lumberjack achievement if I mine enough trees' do
    Game.config.achievements['Lumberjack'].quantity = 10

    (1..20).each do |x|
      item = 720
      @zone.update_block nil, x, 0, FRONT, item
      BlockMineCommand.new([x, 0, FRONT, item, 0], @one.connection).execute!
    end

    msgs = Message.receive_many(@o_sock, only: :achievement)
    msgs.size.should == 1
    msgs.first.should_not be_blank
    msgs.first.data.first.should == ['Lumberjack', 2000]
    @one.progress['trees mined'].should == 20
  end

end
