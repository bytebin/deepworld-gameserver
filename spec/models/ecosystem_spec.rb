require 'spec_helper'
include EntityHelpers

describe Ecosystem do

  context 'with a zone' do
    before(:each) do
      # Create and load up zone with a login
      @zone = ZoneFoundry.create
      with_a_player(@zone)

      @zone = Game.zones[@zone.id]

      @ecosystem = @zone.send("ecosystem")
    end

    it 'should find players in range' do
      tp = add_entity(@zone, 'terrapus/adult', 1, @one.position)
      @ecosystem.players_in_range(tp.position, 5).should eq [@one]
    end

    it 'should not explode finding players in range if entity position not set' do
      tp = add_entity(@zone, 'terrapus/adult', 1, @one.position)
      tp.position = nil

      @ecosystem.players_in_range(tp.position, 5).should eq []
    end

    it 'should not explode finding players in range if player position not set' do
      tp = add_entity(@zone, 'terrapus/adult')
      @one.position = nil

      @ecosystem.players_in_range(tp.position, 1000).should eq []
    end

  end
end
