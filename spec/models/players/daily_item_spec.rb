require 'spec_helper'

describe Players::DailyItem do

  before(:each) do
    with_a_zone
    with_a_player(@zone, level: 2, xp: 2000)

    stub_date Time.new(2014, 12, 1, 20)
    @item = stub_item('rarez', 'title' => 'The Rarez')
    @item_female = stub_item('female_rarez', 'title' => 'The Female Rarez')
    @wardrobe_item = stub_item('clothz', 'wardrobe' => true, 'title' => 'The Clothz')
  end

  describe 'config' do

    before(:each) do
      Game.config.daily_bonuses = Hashie::Mash.new({
        '2014-12-01' => { 'item' => 'rarez', 'item_female' => 'female_rarez', 'xp' => 1500, 'quantity' => 7 },
        '2014-12-02' => { 'item' => 'clothz' }
      })
    end

    it 'should load latest daily item info' do
      Players::DailyItem.item(@one).should eq @item
      Players::DailyItem.quantity.should eq 7
      Players::DailyItem.description(@one).should eq '7 x The Rarez'
      Players::DailyItem.requirement.should eq 1500
    end

    it 'should load female daily item info' do
      @one.settings['lootPreference'] = 1
      Players::DailyItem.item(@one).should eq @item_female
      Players::DailyItem.description(@one).should eq '7 x The Female Rarez'
    end

    it 'should change over daily item info' do
      @one.add_xp 500
      stub_date Time.new(2014, 12, 2, 20)
      Players::DailyItem.item(@one).should eq @wardrobe_item
      Players::DailyItem.quantity.should eq 1
      Players::DailyItem.description(@one).should eq 'The Clothz'
      Players::DailyItem.requirement.should eq 1000
    end

    it 'should default to random loot' do
      stub_date Time.new(2014, 12, 15, 20)
      Players::DailyItem.item(@one).should be_nil
      @one.add_xp 100
      receive_msg!(@one, :notification).data.to_s.should =~ /Random Loot/
    end

  end

  describe 'earning' do

    before(:each) do
      @item = stub_item('rarez')
      Players::DailyItem.stub(:item).and_return(@item)
      Players::DailyItem.stub(:quantity).and_return(2)
      Players::DailyItem.stub(:description).and_return('Awesome rarez bro')
      Players::DailyItem.stub(:requirement).and_return(1000)
    end

    it 'should record daily XP' do
      @one.add_xp 500
      @one.add_xp 150
      @one.xp_daily.should eq({ '2014-12-01' => 650 })
    end

    it 'should notify me if I get halfway to daily item' do
      @one.add_xp 300
      @one.add_xp 300
      msg = receive_many(@one, :notification).last.data.to_s
      msg.should =~ /halfway/
      msg.should =~ /400xp to go/
    end

    it 'should not notify me more than once about getting halfway to daily item' do
      @one.add_xp 300
      @one.add_xp 300
      @one.add_xp 300
      receive_many(@one, :notification).size.should eq 2
    end

    it 'should notify me and reward me with daily INVENTORY item' do
      2.times { @one.add_xp 500 }
      receive_msg!(@one, :inventory).data.should eq [{ @item.code.to_s => [2, 'i', -1] }]
      msg = receive_many(@one, :notification).last.data.to_s
      msg.should =~ /earned/
      msg.should =~ /Awesome rarez bro/
      @one.inv.quantity(@item.code).should eq 2
    end

    it 'should notify me and reward me with daily WARDROBE item' do
      Players::DailyItem.stub(:item).and_return(@wardrobe_item)
      2.times { @one.add_xp 500 }
      receive_msg!(@one, :wardrobe).data.should eq [[@wardrobe_item.code]]
      @one.wardrobe.should include(@wardrobe_item.code)
    end

    it 'should not notify me or reward me again with daily item' do
      10.times { @one.add_xp 500 }
      @one.inv.quantity(@item.code).should eq 2
    end

    it 'should let me get the daily item for the next day' do
      2.times { @one.add_xp 500 }

      stub_date Time.new(2014, 12, 2, 20)
      @item2 = stub_item('moar_rarez')
      Players::DailyItem.stub(:item).and_return(@item2)
      Players::DailyItem.stub(:quantity).and_return(5)
      Players::DailyItem.stub(:description).and_return('Awesomer rarez bro')
      Players::DailyItem.stub(:requirement).and_return(1500)

      2.times { @one.add_xp 800 }
      @one.xp_daily.should eq({ '2014-12-01' => 1000, '2014-12-02' => 1600 })
      @one.inv.quantity(@item.code).should eq 2
      @one.inv.quantity(@item2.code).should eq 5
    end

    it 'should give me random loot for a no-config day' do
      Players::DailyItem.stub(:item).and_return(nil)
      Players::DailyItem.stub(:quantity).and_return(1)
      Players::DailyItem.stub(:requirement).and_return(1000)

      10.times { @one.add_xp 500 }
      @one.items_looted_hash.size.should eq 1
    end

  end

end