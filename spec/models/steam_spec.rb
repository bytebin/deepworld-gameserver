require 'spec_helper'

describe :steam do
  before(:each) do
    Game.steam_enabled = false
    with_a_zone
    with_a_player @zone

    @zone.update_block nil, 11, 4, BASE, Game.item_code('base/vent')

    @collector_code = Game.item_code('mechanical/collector')
    @pipe_code = Game.item_code('mechanical/pipe')
  end

  describe 'with a properly placed collector' do

    before(:each) do
      @zone.update_block nil, 10, 5, FRONT, @collector_code
      @pipe_position = Vector2[13, 4] # Right connector
      lay_pipe Vector2[1, 0], 5
      lay_pipe Vector2[0, 1], 3
      lay_pipe Vector2[1, 0], 2
      @zone.steam = ZoneKernel::Steam.new(@zone.kernel)
      Game.steam_enabled = true
    end

    describe 'with a properly placed forge' do

      before(:each) do
        @zone.update_block nil, @pipe_position.x, @pipe_position.y, FRONT, Game.item_code('mechanical/forge')
      end

      it 'should update the forge as active' do
        @zone.steam_step!
        @zone.peek(@pipe_position.x, @pipe_position.y, FRONT)[1].should == 1
      end

    end

  end

  def lay_pipe(direction, quantity)
    quantity.times do
      @zone.update_block nil, @pipe_position.x, @pipe_position.y, FRONT, @pipe_code
      @pipe_position += direction
    end
  end
end