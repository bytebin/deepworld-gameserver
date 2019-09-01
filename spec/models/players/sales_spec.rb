require 'spec_helper'

describe Players::Sales do

  before(:each) do
    with_a_zone
    with_a_player
    @one.current_client_version = '2.0.4'
    @one.stub(:session_play_time).and_return(600)
    @one.stub(:next_sale_step_at).and_return(Time.new(2014, 1, 1))
    @one.stub(:hint?).and_return(false)

    Game.config.base.shop.stub(:sales).and_return(Hashie::Mash.new({
      'segments' => { 'primary' => ['one', 'two'], 'secondary' => ['three'] }
    }))
    stub_items []
  end

  def stub_items(items)
    Game.config.base.shop.sales.stub(:periodic_items).and_return(items.map{ |i| Hashie::Mash.new(i) })
  end

  it 'should should assign a player sales segments' do
    @one.step_sales true
    @one.segment('primary').should =~ /one|two/
    @one.segment('secondary').should eq 'three'
  end

  it 'should should not reassign a player sales segments' do
    @one.segments['secondary'] = 'six'
    @one.step_sales true
    @one.segment('secondary').should eq 'six'
  end

  describe 'non-recurring' do

    before(:each) do
      stub_items [{ 'key' => 'delay_item', 'delay' => 3600, 'action' => ['shop', 'shop-item'] }]
    end

    it 'should show next sale only after a delay' do
      @one.step_sales
      receive_msg(@one, :dialog).should be_nil

      time_travel 1.1.hours
      @one.step_sales
      receive_msg!(@one, :dialog).data.to_s.should =~ /shop\-item/
    end

    it 'should not show non-recurring sales more than once' do
      2.times do |t|
        time_travel 1.1.hours
        @one.step_sales
        receive_msg(@one, :dialog).should be_a(t == 1 ? NilClass : DialogMessage)
      end
    end

    it 'should show sales out of order based on delay' do
      stub_items [
        { 'key' => 'long_delay', 'delay' => 7200, 'action' => ['shop', 'long-item'] },
        { 'key' => 'short_delay', 'delay' => 3600, 'action' => ['shop', 'short-item'] }
      ]

      time_travel 1.1.hours
      @one.step_sales
      receive_msg(@one, :dialog).data.to_s.should =~ /short\-item/

      time_travel 2.1.hours
      @one.step_sales
      receive_msg(@one, :dialog).data.to_s.should =~ /long\-item/
    end

  end

  describe 'recurring' do

    before(:each) do
      stub_items [{ 'key' => 'recurring_item', 'delay' => 3600, 'recur' => 3, 'action' => ['shop', 'shop-item'] }]
    end

    it 'should track shown sales' do
      2.times do |t|
        time_travel 1.1.hours
        @one.step_sales
      end

      @one.sales_shown['recurring_item'].should eq 2
    end

    it 'should should a player recurring sales' do
      4.times do |t|
        time_travel 1.1.hours
        @one.step_sales
        receive_msg(@one, :dialog).should be_a(t == 3 ? NilClass : DialogMessage)
      end
    end

  end

  it 'should not show sales outside their availability' do
    stub_items [{ 'key' => 'recurring_item', 'delay' => 3600, 'action' => ['shop', 'shop-item'], 'available_after' => [6, 1], 'available_until' => [6,30] }]
    @one.last_damaged_at = Time.new(2014, 5, 14)
    @one.last_sale_at = Time.new(2014, 5, 14)

    stub_date Time.new(2014, 5, 15)
    @one.step_sales
    receive_msg(@one, :dialog).should be_nil

    stub_date Time.new(2014, 6, 15)
    @one.step_sales
    receive_msg(@one, :dialog).should_not be_nil

    stub_date Time.new(2014, 7, 15)
    @one.step_sales
    receive_msg(@one, :dialog).should be_nil
  end

  it 'should follow requirements to show certain sales' do
    stub_items [{ 'key' => 'recurring_item', 'delay' => 3600, 'action' => ['shop', 'req-item'], 'requirements' => ['is_cool', 'is_awesome'] }]

    @one.stub(:is_cool?).and_return(false)
    @one.stub(:is_awesome?).and_return(false)
    @one.last_sale_at -= 1.1.hours
    @one.step_sales
    receive_msg(@one, :dialog).should be_nil

    @one.stub(:is_cool?).and_return(true)
    @one.last_sale_at -= 1.1.hours
    @one.step_sales
    receive_msg(@one, :dialog).should be_nil

    @one.stub(:is_awesome?).and_return(true)
    @one.last_sale_at -= 1.1.hours
    @one.step_sales
    receive_msg!(@one, :dialog).data.to_s.should =~ /req\-item/
  end

end
