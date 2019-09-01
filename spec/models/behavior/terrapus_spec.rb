require 'spec_helper'
include EntityHelpers

describe 'terrapus' do
  TERRAPI = ['terrapus/child']#, 'terrapus/adult', 'terrapus/fire', 'terrapus/acid']

  before(:each) do
    @zone = ZoneFoundry.create
    @air = find_item(@zone, 0, FRONT)

    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
  end

  TERRAPI.each do |entity_key|
    it "should move a #{entity_key}" do
      @entity = add_entity(@zone, entity_key, 1, @air)

      behave_entity(@entity, 24)
      @entity.position.should_not eq @air
    end
  end
end