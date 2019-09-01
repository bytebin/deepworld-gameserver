require 'spec_helper'

describe ZoneSearcher do

  before(:each) do
    @zone1 = ZoneFoundry.create(biome: 'hell')
    @zone2 = ZoneFoundry.create(biome: 'hell')

    @zone3 = ZoneFoundry.create(biome: 'plain', name: 'Plainypants')
    @zone4 = ZoneFoundry.create(biome: 'plain')
  end

  it 'should give me a random hell zone' do
    zone = nil

    Zone.where(biome: 'hell').random do |z|
      zone = z.first
    end

    eventually { [@zone1.id, @zone2.id].should include zone.id}
  end

  it 'should give me a random plain zone' do
    zone = nil

    Zone.where(biome: 'plain').random do |z|
      zone = z.first
    end

    eventually { [@zone3.id, @zone4.id].should include zone.id}
  end
end