require 'spec_helper'

describe Rewards::Loot do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty)
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    Game.play
  end

  describe 'crowns' do

    before(:each) do
      @config = { items: [{ 'crowns' => 10, 'frequency' => 100, 'type' => 'treasure' }],
                 types: 'treasure' }
    end

    it 'should award crowns' do
      @one.premium = false
      Rewards::Loot.new(@one, @config).reward!
      reactor_wait

      @one.crowns.should eq 10
      receive_msg!(@one, :dialog).data.to_s.should =~ /Upgrade to premium/
    end

    it 'should double crown loot for premium players' do
      @one.premium = true
      Rewards::Loot.new(@one, @config).reward!
      reactor_wait

      @one.crowns.should eq 20
      receive_msg!(@one, :dialog).data.to_s.should_not =~ /Upgrade to premium/
    end

  end

  describe 'wardrobe' do

    it 'should give the player wardrobe loot' do
      config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe' }],
                 types: 'wardrobe' }

      Rewards::Loot.new(@one, config).reward!
      reactor_wait

      @one.wardrobe.should include(Game.item_code('tops/charlie-brown'))
    end

    it 'should not give the player wardrobe he/she already has' do
      @one.wardrobe = [Game.item_code('tops/charlie-brown')]
      config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 99999999, 'type' => 'wardrobe' },
                            { 'wardrobe' => 'tops/tesla', 'frequency' => 100, 'type' => 'wardrobe' }],
                 types: 'wardrobe' }

      Rewards::Loot.new(@one, config).reward!
      reactor_wait

      @one.wardrobe.should include(Game.item_code('tops/tesla'))
    end

  end

  it 'should not give a free player premium loot' do
    @one.update premium: false

    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 99999999, 'premium' => true, 'type' => 'wardrobe' },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 100, 'type' => 'wardrobe' }],
               types: 'wardrobe' }

    Rewards::Loot.new(@one, config).reward!
    reactor_wait

    @one.wardrobe.should eq [Game.item_code('tops/tesla')]
  end

  it 'should give the player item loot' do
    Game.clear_inventory_changes

    config = { items: [{ 'items' => [['ground/crystal-blue-1', 10], 'building/iron'], 'frequency' => 100, 'type' => 'resources' }],
               types: 'resources' }

    Rewards::Loot.new(@one, config).reward!

    @one.inv.quantity(Game.item_code('ground/crystal-blue-1')).should eq 10
    @one.inv.quantity(Game.item_code('building/iron')).should eq 1

    # Track inventory changes
    Game.write_inventory_changes
    eventually do
      inv = collection(:inventory_changes).find.first
      inv.should_not be_blank
      inv['p'].should eq @one.id
      inv['z'].should eq @zone.id
      inv['i'].should eq Game.item_code('ground/crystal-blue-1')
      inv['q'].should eq 10
    end
  end

  it 'should not give player incorrect type of loot' do
    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe' }],
               types: 'resources' }

    Rewards::Loot.new(@one, config).reward!
    reactor_wait

    @one.wardrobe.should_not include(Game.item_code('tops/charlie-brown'))
  end

  it 'should never give rare items with low luck' do
    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe' },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 10, 'type' => 'wardrobe' }],
               types: 'wardrobe' }
    Rewards::Loot.new(@one, config).options.size.should == 1
  end

  it 'should give rare items with high luck' do
    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe' },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 10, 'type' => 'wardrobe' }],
               types: 'wardrobe' }
    @one.skills['luck'] = 10
    Rewards::Loot.new(@one, config).options.size.should == 2
  end

  it 'should give specific items' do
    Rewards::Loot.new(@one, static: { 'tools/pickaxe-fine' => 10 }).reward!
    @one.inv.quantity(Game.item_code('tools/pickaxe-fine')).should eq 10
  end

  it 'should give more items with higher luck' do
    config = { items: [{ 'items' => [['building/wood', 10], 'building/iron'], 'frequency' => 100, 'type' => 'resources' }],
               types: 'resources' }

    @one.skills['luck'] = 10
    Rewards::Loot.new(@one, config).reward!

    qty = @one.inv.quantity(Game.item_code('building/wood'))
    qty.should > 10
    qty.should < 30
    @one.inv.quantity(Game.item_code('building/iron')).should eq 1 # Single items shouldn't give more
  end

  it 'should give non-live items when in staging' do
    Rewards::Loot.stub(:live_only?).and_return(false)

    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe', 'live' => false },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 100, 'type' => 'wardrobe' }],
               types: 'wardrobe' }
    Rewards::Loot.new(@one, config).options.size.should == 2
    Rewards::Loot.new(@one, config).options.to_s.should =~ /charlie/
  end

  it 'should not give non-live items when in production' do
    Rewards::Loot.stub(:live_only?).and_return(true)

    config = { items: [{ 'wardrobe' => 'tops/charlie-brown', 'frequency' => 100, 'type' => 'wardrobe', 'live' => false },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 100, 'type' => 'wardrobe' }],
               types: 'wardrobe' }
    Rewards::Loot.new(@one, config).options.to_s.should_not =~ /charlie/
    Rewards::Loot.new(@one, config).options.size.should eq 1
  end

  it 'should not give items that are not in config' do
    Rewards::Loot.stub(:live_only?).and_return(true)

    config = { items: [{ 'wardrobe' => 'tops/charlie-brown-the-clown', 'frequency' => 100, 'type' => 'wardrobe' },
                          { 'items' => [['building/wood', 10], ['building/iron-thingy', 2]], 'frequency' => 100, 'type' => 'resources' },
                          { 'wardrobe' => 'tops/tesla', 'frequency' => 100, 'type' => 'wardrobe' }],
               types: ['wardrobe', 'resources'] }
    Rewards::Loot.new(@one, config).options.to_s.should_not =~ /charlie/
    Rewards::Loot.new(@one, config).options.to_s.should_not =~ /iron/
    Rewards::Loot.new(@one, config).options.to_s.should =~ /tesla/
    Rewards::Loot.new(@one, config).options.size.should eq 1
  end

  it 'should be configured with working items' do
    @config = YAML.load_file('models/rewards/loot.yml')
    @config.each do |option|
      if option['wardrobe']
        Game.item(option['wardrobe']).try(:id).should eq(option['wardrobe']), "loot #{option} is not a wardrobe item"
      else
        option['type'].to_s.should match(/^(treasure\+?|armaments\+?|resources)$/), "loot #{option} is invalid"
      end

      if items = option['items']
        [*items].each do |item|
          item_name = item.is_a?(Array) ? item.first : item
          Game.item(item_name).should_not be_nil, "Item named #{item_name} is invalid"
        end
      end
    end
  end

  it 'should be configured to not give away rare items too often' do
    @one.skills['luck'] = 10

    cfg = YAML.load_file('models/rewards/loot.yml')

    normal_rarity = Rewards::Loot.new(@one, items: cfg, types: ['treasure', 'armaments']).rarity
    quality_rarity = Rewards::Loot.new(@one, items: cfg, types: ['treasure+', 'armaments+']).rarity

    normal_rarity['accessories'].should < 0.132
    quality_rarity['accessories'].should < 0.18
  end

  it 'should bestow more attempts on players with high luck' do
    @one.skills['luck'] = 2
    Rewards::Loot.new(@one).attempts.should eq 1
    @one.skills['luck'] = 8
    Rewards::Loot.new(@one).attempts.should eq 1
    @one.skills['luck'] = 10
    Rewards::Loot.new(@one).attempts.should eq 2
    @one.skills['luck'] = 14
    Rewards::Loot.new(@one).attempts.should eq 2
    @one.skills['luck'] = 15
    Rewards::Loot.new(@one).attempts.should eq 3
  end

  describe "bonus items" do

    it 'should not bestow bonus items when bonus is not active' do
      @config = { items: [{ 'crowns' => 10, 'frequency' => 100, 'type' => 'treasure', 'bonus' => 'crowns' }],
                   types: 'treasure' }
      Rewards::Loot.new(@one, @config).reward!
      reactor_wait
      @one.crowns.should eq 0
    end

    it 'should bestow bonus items when bonus is active' do
      @config = { items: [{ 'crowns' => 10, 'frequency' => 100, 'type' => 'treasure', 'bonus' => 'crowns' }],
                   types: 'treasure' }
      Game.schedule.add type: "loot_bonus", bonus: ["crowns"], expire_at: Time.now.to_i + 5.seconds
      Rewards::Loot.new(@one, @config).reward!
      reactor_wait
      @one.crowns.should eq 10
    end

  end
end
