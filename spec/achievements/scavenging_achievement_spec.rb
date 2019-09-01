require 'spec_helper'

describe Achievements::ScavengingAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]

    extend_player_reach @one
  end

  def mine(ct, items, block_owner = nil, reset = false)
    @i = 0 if reset || @i.nil?
    ct.times do
      item = items[@i].to_i
      @zone.update_block nil, @i, 0, FRONT, item, 0, block_owner
      BlockMineCommand.new([@i, 0, FRONT, item, 0], @one.connection).execute!
      @i += 1
    end
  end

  describe 'scavenging' do

    before(:each) do
      @items = Game.item_search(/building/).values.map(&:code)
    end

    it 'should award me with a scavenger achievement if I mine enough ore' do
      mine 10, @items
      msgs = Message.receive_many(@o_sock, only: :achievement)
      msgs.size.should == 1
      msgs.first.should_not be_blank
      msgs.first.data.first.should == ['Scavenger', 2000]
    end

    it 'should notify me when I pass 25% threshold of scavenging' do
      mine 2, @items
      Message.receive_one(@o_sock, only: :notification).should be_blank
      mine 1, @items
      msg = Message.receive_one(@o_sock, only: :notification)
      msg.should_not be_blank
      msg.data.to_s.should =~ /mined 3 kinds of items/
      msg.data.to_s.should =~ /quarter/
      msg.data.to_s.should =~ /Scavenger/
    end

    it 'should notify me when I pass 50% threshold of scavenging' do
      mine 5, @items
      msg = Message.receive_many(@o_sock, only: :notification).last
      msg.should_not be_blank
      msg.data.to_s.should =~ /halfway/
    end

  end

  describe 'foraging' do

    before(:each) do
      @one.achievements["Scavenger"] = {}
    end

    it 'should award me with a foraging achievement' do
      foraging_items = Achievements::ScavengingAchievement.foraging_types
      mine foraging_items.size - 1, foraging_items
      @one.items_discovered_hash.size.should eq foraging_items.size-1
      Message.receive_one(@o_sock, only: :achievement).should be_blank
      mine 1, foraging_items

      msg = Message.receive_one(@o_sock, only: :achievement)
      msg.should_not be_blank
      msg.data.first.should == ['Forager', 5000]
    end

    it 'should not award foraging achievement for mining player-placed vegetation' do
      foraging_items = Achievements::ScavengingAchievement.foraging_types
      mine foraging_items.size, foraging_items, @one
      @one.items_discovered_hash.size.should eq 0
      Message.receive_one(@o_sock, only: :achievement).should be_blank
    end

  end

  describe 'horticulturalist' do

    it 'should award me with a horticulturalist achievement' do
      items = Achievements::ScavengingAchievement.horticulturalist_types
      mine items.size - 1, items
      @one.items_discovered_hash.size.should eq items.size-1
      Message.receive_one(@o_sock, only: :achievement).should be_blank
      mine 1, items
      Message.receive_one(@o_sock, only: :achievement).should be_blank
      9.times do
        mine items.size, items, nil, true
      end

      msg = Message.receive_one(@o_sock, only: :achievement)
      msg.should_not be_blank
      msg.data.first.should == ['Horticulturalist', 10000]
    end

  end

end
