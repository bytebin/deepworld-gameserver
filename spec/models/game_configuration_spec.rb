require 'spec_helper'
include EntityHelpers

describe GameConfiguration do

  describe 'with a shop full of stuff' do
    before(:each) do
      @player = PlayerFoundry.create
      @items = ProductFoundry.shop!
      refresh_products
    end

    it 'should update to enabled products' do
      previous = Game.config.data(@player, true)['shop']['currency'].keys

      # Disable a couple and add a couple
      disabled = previous.random(2)
      disabled.each {|c| collection(:products).update({code: c}, {'$set' => {enabled: false}}) }
      newer = ProductFoundry.many!(2).map(&:code)

      refresh_products

      config = Game.config.data(@player, true)
      eventually {
        config['shop']['currency'].keys.should =~ previous - disabled + newer
      }
    end

    it "should show a premium iap for a free player" do
      @player.premium = false

      config = Game.config.data(@player, true)
      config['shop']['premium'].should_not be_nil
      config['shop']['currency'].length.should eq 5
    end

    it "should not show a premium iap for a premium player" do
      @player.premium = true

      config = Game.config.data(@player, true)
      config['shop']['premium'].should be_nil
      config['shop']['currency'].length.should eq 6
    end
  end

  describe 'version-specific config' do

    before(:each) do
      GameConfiguration.stub(:packed_version).and_return('2.2.0')
      @player = PlayerFoundry.create
      Game.config.stub(:base).and_return(Hashie::Mash.new({ 'one' => { 'a' => 'b' }, 'two' => { 'c' => 'd' }, 'items' => { 'one' => 1 }, 'packed_items' => { 'one' => 2, 'packed' => true }}))
      Game.config.cache_versions({ '1.0.0' => { 'two' => { 'e' => 'f' }}, '2.2.0' => {}, '2.2.1' => { 'items' => { 'one' => 3 }, 'packed_items' => { 'one' => 4 }}})
    end

    it 'should merge additional config if a player has a new enough client' do
      @player.current_client_version = '1.1.0'
      Game.config.data(@player, true)['two']['e'].should eq 'f'
    end

    it 'should not merge additional config if a player has an old client' do
      @player.current_client_version = '0.9.0'
      Game.config.data(@player, true)['two']['e'].should be_nil
    end

    it 'should not include packed items separately' do
      cfg = Game.config.data(@player, true)
      cfg['packed_items'].should be_blank
      cfg['packed_item_keys'].should be_blank
    end

    it 'should not add packed items for older clients' do
      @player.current_client_version = '2.0.0'
      cfg = Game.config.data(@player, true)
      cfg['items']['one'].should eq 1
    end

    it 'should replace items with packed items' do
      @player.current_client_version = '2.2.0'
      cfg = Game.config.data(@player, true)
      cfg['items']['packed'].should eq true
      cfg['items']['one'].should eq 2
    end

    it 'should replace versioned items with packed items' do
      @player.current_client_version = '2.2.1'
      cfg = Game.config.data(@player, true)
      cfg['packed_items'].should be_blank
      cfg['items']['one'].should eq 4
    end

  end

  def refresh_products
    refreshed = false

    Game.config.refresh_products do
      refreshed = true
    end

    eventually { refreshed.should eq true }
  end
end
