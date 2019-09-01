require 'spec_helper'

describe ZoneSearchCommand do

  it "should return random zones" do
    zones = {}
    50.times.each {z = ZoneFoundry.create; zones[z.id.to_s] = z}
    with_a_player(zones.values.first)
    @one.premium = true

    results = zone_search('Random').map{|z| zones[z.to_s].id }

    3.times do
      next_res = zone_search('Random').map{|z| zones[z.to_s].id }
      next_res.count.should >= 9
      (next_res - results).should_not be_blank, "Not random!"
    end
  end

  context 'with a few zones' do
    before(:each) do
      with_a_zone
      with_3_players(@zone)
      @one.premium = true

      @zone1 = ZoneFoundry.create(name: 'Whatever')
      @zone2 = ZoneFoundry.create
      @zone3 = ZoneFoundry.create(biome: 'hell')
    end

    it "should not show static zones" do
      @zone4 = ZoneFoundry.create(static: true)
      zone_search('Random').should_not include(@zone4.id.to_s)
    end

    it "should not return the player's current zone" do
      zone_search('Recent').should_not include(@zone.id.to_s)
    end

    it "should return recently visited zones" do
      @one.visited_zones = [@zone1.id]
      zone_search('Recent').should include(@zone1.id.to_s)
    end

    it "should return a recently visited beginner zone" do
      @zonebeg = ZoneFoundry.create(scenario: 'Beginner')
      @one.visited_zones = [@zonebeg.id]

      zone_search('Recent').should include(@zonebeg.id.to_s)
    end

    it "should return a searched zone" do
      zone_search('Whatever').should eq [@zone1.id.to_s]
    end

    it "should not explode on regex problem for search" do
      @zone4 = ZoneFoundry.create(name: '(Whatever')
      zone_search('(Whatever').should eq [@zone4.id.to_s]
    end

    it "should return a player's private zones" do
      @zone1.update private: true
      @zone2.update private: true
      @one.owned_zones = [@zone1.id]
      @one.member_zones = [@zone2.id]
      zone_search('Private').should =~ [@zone1.id.to_s, @zone2.id.to_s]
    end

    it "should not return other players' private zones" do
      @zone1.update private: true
      @zone2.update private: true
      @zone3.update private: true
      @two.owned_zones = [@zone1.id]
      @two.member_zones = [@zone2.id]
      @one.owned_zones = [@zone3.id]
      zone_search('Private').should == [@zone3.id.to_s]
    end

    it "should not return zones where a players' followees are active, but hidden" do
      @three, @t_sock = auth_context(@zone3, settings: {visibility: 2})
      @one.follow @three

      zone_search('Friends').should be_blank
    end

    it "should not return zones where a players' followees are active, but not visible" do
      @three, @t_sock = auth_context(@zone3, settings: {visibility: 1})
      @one.follow @three
      [@one, @three].each {|p| p.reload}

      zone_search('Friends').should be_blank
    end

    it "should return zones where a players' reciprocal followees are active" do
      @three, @t_sock = auth_context(@zone3, settings: {visibility: 1})
      @one.follow @three
      @three.follow @one
      [@one, @three].each {|p| p.reload}

      zone_search('Friends').should eq [@zone3.id.to_s]
    end

    it "should return zones where a players' followees are active" do
      @three, @t_sock = auth_context(@zone3)

      @one.follow @three

      search = zone_search('Friends', nil).first
      search[0].should == @zone3.id.to_s
      search[3].should == 1
      search[4].should == [@three.name]
    end

    it "should return zones where a players' followees are active and is a shared private zone" do
      @zone3.update private: true
      @three, @t_sock = auth_context(@zone3)

      @one.follow @three
      @one.member_zones = [@zone3.id]
      @three.member_zones = [@zone3.id]
      zone_search('Friends').should == [@zone3.id.to_s]
    end

    it "should not return zones where a players' followees are active but are their own private zone" do
      @zone3.update private: true
      @three, @t_sock = auth_context(@zone3)
      @one.follow @three
      @three.member_zones = [@zone3.id]
      zone_search('Friends').should be_blank
    end

    it "should limit to max players count" do
      @zone3.update players_count: Deepworld::Settings.search.max_players + 1
      @zone2.update players_count: Deepworld::Settings.search.max_players
      @zone1.update players_count: Deepworld::Settings.search.max_players - 1

      zone_search('Popular').should =~ [@zone2.id.to_s, @zone1.id.to_s]
    end

    it "should not show me a market zone in popular" do
      market = ZoneFoundry.create(market: true)

      market.update players_count: Deepworld::Settings.search.max_players - 2
      @zone2.update players_count: Deepworld::Settings.search.max_players - 2
      @zone1.update players_count: Deepworld::Settings.search.max_players - 1

      zone_search('Popular').should =~ [@zone2.id.to_s, @zone1.id.to_s]
    end
  end

  describe 'accessibility' do

    before(:each) do
      with_a_zone private: true
      with_a_player
      4.times { ZoneFoundry.create premium: false }
      3.times { ZoneFoundry.create premium: true }
      ZoneFoundry.create premium: false, biome: 'hell'
      ZoneFoundry.create premium: false, biome: 'arctic'
      ZoneFoundry.create premium: false, biome: 'desert'
    end

    it 'should send all zones as accessible if a player is premium' do
      @one.premium = true
      zone_search('Untouched', :accessibility).should =~ ['a']*7 + ['p']*3
    end

    pending 'should send biome zones as inaccessible if a player is not premium and does not have upgrades' do
      @one.premium = false
      zone_search('Untouched', :accessibility).should =~ ['a']*4 + ['i']*3 + ['p']*3
    end

  end

  context 'with a bunch of free and premium zones' do
    before(:each) do
      @free = 10.times.map{ ZoneFoundry.create(premium: false)}
      @premium = 10.times.map{ ZoneFoundry.create(premium: true)}

      with_a_zone
      with_a_player
    end

    it "should send a free player a few teaser zones" do
      pending "Stopped working"
      @one.premium = false

      zone_search('Untouched', :premium).should =~ ['a']*7 + ['p']*3
    end
  end

  # Helpers

  def zone_search(type, retrieve = :id)
    Message.new(:zone_search, [type]).send(@one.socket)
    zones = receive_msg!(@one, :zone_search).data[3]

    case retrieve
    when :id
      zones.map{ |z| z.first }
    when :premium
      zones.map{ |z| z[9] }
    when :accessibility
      zones.map{ |z| z[9] }
    else
      zones
    end
  end
end
