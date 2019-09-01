require 'spec_helper'

describe Achievements::DiscoveryAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    extend_player_reach @one
  end

  describe 'teleporter discovery' do
    it 'should reward me when I find enough teleporters' do
      (1..5).each do |x|
        @zone.update_block nil, x, 1, FRONT, Game.item_code('mechanical/teleporter')
        @zone.set_meta_block x, 1, nil
        Message.new(:block_use, [x, 1, FRONT, nil]).send(@o_sock)
      end

      msg = Message.receive_one(@o_sock, only: :achievement)
      msg.should_not be_nil
      msg[:key].should eq ['Teleporter Repairman']
    end
  end

  describe 'purifier discovery' do
    it 'should reward me when I find enough purifier parts' do
      geck_parts = %w{tank-base tank hoses tree-base tree-top cog-large cog-small}.map{ |g| "mechanical/geck-#{g}" }

      # Add chests with GECK parts
      (1..4).each do |x|
        part = geck_parts.random
        chest = Game.item_code('containers/chest')
        @zone.update_block nil, x, 1, FRONT, chest
        @zone.set_meta_block x, 1, chest, nil, { '$' => Game.item_code(part) }
        command! @one, :block_use, [x, 1, FRONT, nil]
      end

      reactor_wait

      # Test one GECK tub as well
      @zone.update_block nil, 10, 1, FRONT, Game.item_code('mechanical/geck-tub')
      @zone.machines_discovered[:geck] = geck_parts.map{ |p| Game.item_code(p) }
      command! @one, :block_use, [10, 1, FRONT, nil]

      msg = receive_msg!(@one, :achievement)
      msg[:key].should eq ['Ecologist']
    end
  end

end