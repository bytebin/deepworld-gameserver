require 'spec_helper'

describe Zone do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :droplets)
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    @one.active_indexes = [0]
  end

  pending 'should deplete liquid by one block' do
    @zone.peek(2, 2, LIQUID).should == [100, 3]
    @zone.peek(5, 3, LIQUID).should == [0, 0]
    total_liquid.should == 21
    
    @zone.step! 0.125
    @zone.liquid_step!

    liquid_at(2, 2).should > 0
    liquid_at(5, 3).should > 0
    liquid_at(6, 3).should > 0
    total_liquid.should == 21

    @zone.liquid_step!

    liquid_at(2, 2).should > 0
    liquid_at(5, 3).should > 0
    liquid_at(6, 3).should > 0
    liquid_at(7, 3).should > 0
    total_liquid.should == 21

    (0..@zone.size.y - 1).each do |y|
      @zone.update_block nil, 10, y, FRONT, 0
      @zone.liquid_step!
      total_liquid.should == 21
    end
  end

  def liquid_at(x, y)
    @zone.peek(x, y, LIQUID).last
  end

  def total_liquid
    (0..@zone.size.y - 1).inject(0) do |total, y| 
      (0..@zone.size.x - 1).each do |x|
        total += @zone.peek(x, y, LIQUID).last
      end
      total
    end
  end
end