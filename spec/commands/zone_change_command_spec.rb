require 'spec_helper'

describe ZoneChangeCommand do

  describe 'public zones' do

    before(:each) do
      @current_zone = ZoneFoundry.create
      @zone1 = ZoneFoundry.create
      @free_zone = ZoneFoundry.create(premium: false)
      @premium_zone = ZoneFoundry.create(premium: true)
      @one, @o_sock = auth_context(@current_zone)
    end

    it "should not let the player teleport to their current zone" do
      zone_change(@current_zone.name).should be_false
      @one.zone_id.should == @current_zone.id
    end

    it "should not let the player teleport to a zone that they don't have enough karma for" do
      @one.karma = @zone1.karma_required - 1

      zone_change(@zone1.id.to_s).should be_false
    end

    it "should let the player teleport to a non-private by ID" do
      p @zone1.premium
      zone_change(@zone1.id.to_s).should be_true
      @one.zone_id.should == @zone1.id
    end

    it "should let the player teleport to a non-private by name" do
      zone_change(@zone1.name).should be_true
      @one.zone_id.should == @zone1.id
    end

    it "should let premium players teleport to free zones" do
      @one.premium = true
      zone_change(@free_zone.id.to_s).should be_true
      @one.zone_id.should == @free_zone.id
    end

    it "should let premium players teleport to premium zones" do
      @one.premium = true
      zone_change(@premium_zone.id.to_s).should be_true
      @one.zone_id.should == @premium_zone.id
    end

    it "should let free players teleport to free zones" do
      @one.premium = false
      zone_change(@free_zone.id.to_s).should be_true
      @one.zone_id.should == @free_zone.id
    end

    it "should not let free players teleport to premium zones" do
      @one.premium = false
      zone_change(@premium_zone.id.to_s).should be_false
    end

    it "should not let free players teleport to premium zones" do
      @one.premium = false
      zone_change(@premium_zone.id.to_s).should be_false
    end

    describe 'biomes' do

      before(:each) do
        @biome_zone = ZoneFoundry.create(premium: false, biome: 'arctic')
      end

      it 'should let premium players teleport to biomes' do
        @one.premium = true
        zone_change(@biome_zone.id.to_s).should be_true
      end

      it 'should let free players teleport to biomes if they have upgrades' do
        @one.premium = false
        @one.upgrades = ['arctic']
        zone_change(@biome_zone.id.to_s).should be_true
      end

      it 'should let free players teleport to biomes if they do not have upgrades' do
        @one.premium = false
        @one.upgrades = ['space']
        zone_change(@biome_zone.id.to_s).should be_true
      end

    end

  end

  describe 'private zones' do

    before(:each) do
      @current_zone = ZoneFoundry.create
      @zone1 = ZoneFoundry.create(private: true)
      @one, @o_sock = auth_context(@current_zone)
    end

    it "should not let the player teleport to a private by ID" do
      zone_change(@zone1.id.to_s).should be_false
      @one.zone_id.should == @current_zone.id
    end

    it "should not let the player teleport to a private by name" do
      zone_change(@zone1.name).should be_false
      @one.zone_id.should == @current_zone.id
    end

  end

  it 'should let me visit my private zone even though I cant access that zone type' do
    @one, @o_sock = auth_context(with_a_zone, premium: false)

    # Dude buys an arctic
    arctic = ZoneFoundry.create(private: true, biome: 'arctic')
    arctic.add_owner(@one)

    zone_change(arctic.id.to_s).should be_true
    @one.zone_id.should eq arctic.id
  end

  # Helpers

  def zone_change(identifier)
    Message.new(:zone_change, [identifier]).send(@o_sock)
    msg = Message.receive_one(@o_sock, only: :kick) ? true : false
  end
end
