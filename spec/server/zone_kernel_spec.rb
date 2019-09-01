require 'spec_helper'

describe 'ZoneKernel' do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @water = find_item(@zone, 100, LIQUID)
    @air = find_item(@zone, 0, FRONT)
    @back_air = find_item(@zone, 0, BACK)

    @zone = Game.zones[@zone.id]
  end

  describe 'querying' do

    describe 'earthyness' do

      # Earthquakes: find base 2, front 0, surrounded by at least two earth blocks
      # Air turds: find base 0, front 512, surrounded by less than three earth blocks

      def fill_in(base)
        (0..19).each do |y|
          (0..19).each do |x|
            @zone.update_block nil, x, y, BASE, base
            @zone.update_block nil, x, y, BACK, 0
            @zone.update_block nil, x, y, FRONT, 0
          end
        end
      end

      it 'should find earth blocks with air beneath them' do
        fill_in 0

        # Find earth with nothing below
        @zone.update_block nil, 1, 1, FRONT, 512

        # Two earths, find only the bottom one
        @zone.update_block nil, 2, 1, FRONT, 512
        @zone.update_block nil, 2, 2, FRONT, 512

        # Blocked by stone, don't find
        @zone.update_block nil, 3, 1, FRONT, 512
        @zone.update_block nil, 3, 2, FRONT, 615

        # Not earth, don't find
        @zone.update_block nil, 4, 1, FRONT, 615

        # Underground, don't find
        @zone.update_block nil, 5, 1, BASE, 2
        @zone.update_block nil, 5, 2, BASE, 2
        @zone.update_block nil, 5, 1, FRONT, 512

        results = @zone.kernel.below_query(0, false, 512, 0)
        results.should =~ [[1, 1], [2, 2]]
      end

      it 'should find blocks to fill in for earthquakes' do
        fill_in 2
        [[5, 4], [7, 4], [5, 5], [7, 5], [5, 6], [7, 6], [5, 7], [7, 7], [5, 8], [7, 8]].each do |v|
          @zone.update_block nil, v[0], v[1], FRONT, 512
        end
        @zone.update_block nil, 6, 7, BACK, Game.item_code('back/stone') # Don't fill - back block

        @zone.kernel.earth_query(0, true, 0, true).should =~ [[6, 5], [6, 6]]
      end

      it 'should find turd air blocks to drop' do
        fill_in 0
        @zone.update_block nil, 5, 5, FRONT, 512 # Drop
        @zone.update_block nil, 6, 5, FRONT, 512 # Drop
        @zone.update_block nil, 8, 5, FRONT, 512 # Drop

        @zone.update_block nil, 10, 5, FRONT, 512 # Don't drop - block below
        @zone.update_block nil, 10, 6, FRONT, Game.item_code('building/stone')

        @zone.update_block nil, 1, 5, FRONT, 512 # Don't drop
        @zone.update_block nil, 2, 5, FRONT, 512 # Don't drop
        @zone.update_block nil, 1, 6, FRONT, 512 # Don't drop
        @zone.update_block nil, 2, 6, FRONT, 512 # Don't drop

        @zone.kernel.earth_query(0, false, 512, false).should eq [[5, 5], [6, 5], [8, 5]]
      end

    end

    describe 'with rays' do

      before(:each) do
        [0, 0, 0, 0, 512, 0, 512, 0, 0, 0, 0, 0].each_with_index{ |i, idx| @zone.update_block nil, idx, 0, FRONT, i }
      end

      it 'should raycast' do
        @zone.raycast(Vector2[0, 0], Vector2[10, 0]).should eq [4, 0]
      end

      pending 'should raycast and stop at liquid' do
        @zone.update_block nil, 2, 0, LIQUID, Game.item_code('liquid/water'), 3
        @zone.raycast(Vector2[0, 0], Vector2[10, 0], true).should eq [2, 0]
      end

      it 'should get all blocks in a ray path' do
        @zone.raypath(Vector2[0, 0,], Vector2[5, 0]).should eq [[0, 0], [1, 0], [2, 0], [3, 0]]
      end

      it 'should get all blocks in a ray path and not be stopped by shelter' do
        @zone.raypath(Vector2[0, 0,], Vector2[5, 0], true, true).should eq [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]
      end

      it 'should get all blocks with items in a ray path' do
        @zone.raypath(Vector2[0, 0,], Vector2[5, 0], true, true, true).should eq [
          [0, 0, [0,0,0,0,0,0,0]],
          [1, 0, [0,0,0,0,0,0,0]],
          [2, 0, [0,0,0,0,0,0,0]],
          [3, 0, [0,0,0,0,0,0,0]],
          [4, 0, [0,0,0,512,0,0,0]]
        ]
      end

    end

    it 'should query all blocks in a chunk' do
      results = @zone.get_chunk(0).query

      results.count.should eq 400
    end

    it 'should query for aboveground blocks' do
      compare = find_items(@zone, 0, BASE).reject{|v| v.x > 19 || v.y > 19}
      results = @zone.get_chunk(0).query(false, nil, nil, nil)

      results.count.should eq 64
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

    it 'should query for underground blocks' do
      compare = find_items(@zone, 2, BASE).reject{|v| v.x > 19 || v.y > 19}
      results = @zone.get_chunk(0).query(true, nil, nil, nil)

      results.count.should eq 336
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

    it 'should query for all back air blocks' do
      compare = find_items(@zone, 0, BACK).reject{|v| v.x > 19 || v.y > 19}
      results = @zone.get_chunk(0).query(nil, 0, nil, nil)

      results.count.should eq 308
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

    it 'should query for all front air blocks' do
      compare = find_items(@zone, 0, FRONT).reject{|v| v.x < 20 || v.x > 39 || v.y > 19}
      results = @zone.get_chunk(1).query(nil, nil, 0, nil)

      results.count.should eq 157
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

    it 'should query for all water blocks' do
      compare = find_items(@zone, 100, LIQUID).reject{|v| v.x > 19 || v.y > 19}
      results = @zone.get_chunk(0).query(nil, nil, nil, 100)

      results.count.should eq 31
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

    it 'should query for all above-ground blocks' do
      compare = find_items(@zone, 0, BASE).reject{|v| v.x > 19 || v.y > 19}
      results = @zone.get_chunk(0).query(false, nil, nil, nil)

      results.count.should eq 64
      compare.collect{|v| [v.x, v.y]}.should =~ results
    end

  end

  it 'should update the LIQUID item' do
    @zone.update_block(nil, @air.x, @air.y, LIQUID, 100, nil)
    @zone.peek(@air.x, @air.y, LIQUID)[0].should eq 100
  end

  it 'should update the LIQUID mod' do
    @zone.update_block(nil, @water.x, @water.y, LIQUID, nil, 5)
    @zone.peek(@water.x, @water.y, LIQUID)[1].should eq 5
  end

  it 'should update the LIQUID item and mod' do
    @zone.update_block(nil, @water.x, @water.y, LIQUID, 100, 5)
    @zone.peek(@water.x, @water.y, LIQUID).should eq [100, 5]
  end

  it 'should update the FRONT item' do
    @zone.update_block(nil, @air.x, @air.y, FRONT, 650, nil)
    @zone.peek(@air.x, @air.y, FRONT)[0].should eq 650
  end

  it 'should update the FRONT mod' do
    @zone.update_block(nil, @air.x, @air.y, FRONT, 0, 5)
    @zone.peek(@air.x, @air.y, FRONT)[1].should eq 5
  end

  it 'should update the FRONT item and mod' do
    @zone.update_block(nil, @air.x, @air.y, FRONT, 650, 5)
    @zone.peek(@air.x, @air.y, FRONT).should eq [650, 5]
  end

  it 'should update the BACK item' do
    @zone.update_block(nil, @back_air.x, @back_air.y, BACK, 250, nil)
    @zone.peek(@back_air.x, @back_air.y, BACK)[0].should eq 250
  end

  it 'should update the BACK mod' do
    @zone.update_block(nil, @back_air.x, @back_air.y, BACK, nil, 5)
    @zone.peek(@back_air.x, @back_air.y, BACK)[1].should eq 5
  end

  it 'should update the BACK item and mod' do
    @zone.update_block(nil, @back_air.x, @back_air.y, BACK, 250, 5)
    @zone.peek(@back_air.x, @back_air.y, BACK).should eq [250, 5]
  end

  # [base.item, back.item, back.mod, front.item, front.mod, liquid.item, liquid.mod]
  it 'should fill an array with peek info' do
    @zone.update_block(nil, 2, 2, BASE, 4, nil)
    @zone.update_block(nil, 2, 2, BACK, 50, 2)
    @zone.update_block(nil, 2, 2, FRONT, 60, 3)
    @zone.update_block(nil, 2, 2, LIQUID, 70, 4)

    @zone.all_peek(2, 2).should eq [4, 50, 2, 60, 3, 70, 4]
  end

  it 'should retain and report the owner of a front block' do
    @zone.update_block(nil,  @air.x, @air.y, FRONT, 650, 0, @one)

    # Validate owner
    @zone.block_owner(@air.x, @air.y, FRONT).should eq @one.digest

    # Validate item and mod
    @zone.peek(@air.x, @air.y, FRONT).should eq [650, 0]
  end

  it 'should retain and report the owner of a back block' do
    @zone.update_block(nil, @back_air.x, @back_air.y, BACK, 250, 0, @one)

    # Validate owner
    @zone.block_owner(@back_air.x, @back_air.y, BACK).should eq @one.digest

    # Validate item and mod
    @zone.peek(@back_air.x, @back_air.y, BACK).should eq [250, 0]
  end

  it 'should clear ownership information' do
    @zone.update_block(nil, @back_air.x, @back_air.y, BACK, 250, 0, @one)
    @zone.update_block(nil,  @air.x, @air.y, FRONT, 650, 0, @one)

    @zone.kernel.clear_owners

    # Validate owners
    @zone.block_owner(@air.x, @air.y, FRONT).should eq 0
    @zone.block_owner(@back_air.x, @back_air.y, BACK).should eq 0

    # Validate item and mod
    @zone.peek(@air.x, @air.y, FRONT).should eq [650, 0]
    @zone.peek(@back_air.x, @back_air.y, BACK).should eq [250, 0]
  end

  pending 'should send chunks correctly when a player has "owned" a block' do
    @zone.update_block(nil, 0, 0, FRONT, 650, 0, @one)

    @two, @t_sock = auth_context(@zone)
    Message.new(:blocks_request, [[0]]).send(@t_sock)
    blocks = Message.receive_one(@t_sock, only: :blocks)

    blocks[:blocks_x].should eq [0]
    blocks[:blocks_y].should eq [0]
  end

  it 'should compute the item counts for a zone' do
    @zone = ZoneFoundry.create(data_path: :twentyempty)
    @zone.kernel.item_counts.should == {}

    @zone.update_block nil, 0, 1, FRONT, 600
    @zone.update_block nil, 0, 2, FRONT, 600
    @zone.update_block nil, 0, 3, FRONT, 975
    @zone.update_block nil, 0, 1, BACK, 514
    @zone.update_block nil, 0, 2, BACK, 514
    @zone.update_block nil, 0, 3, BACK, 517

    @zone.kernel.item_counts.should == {514=>2, 517=>1, 600=>2, 975=>1}
  end

  it 'should pack chunk data directly' do
    (0..30).each{ |x| @zone.update_block nil, x, 0, FRONT, x, x }
    (0..30).each{ |x| @zone.update_block nil, x, 1, BACK, x, x }

    # Ruby packing
    ch = BlocksMessage.new(Chunk.many(@zone, [0, 1]).map{|c| c.to_a(true)}).data[0]

    # C packing
    ch2 = @zone.chunk_data([0, 1])
    unpacked = MessagePack.unpack(ch2)

    unpacked[0][0..3].should eq ch[0][0..3]
    unpacked[0].should eq ch[0]
    unpacked[1].should eq ch[1]
    unpacked.should eq ch
  end
end
