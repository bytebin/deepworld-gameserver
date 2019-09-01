require 'spec_helper'

describe ZoneKernel::Growth do

  describe 'functionality' do

    before(:each) do
      @zone = with_a_zone(data_path: :twohundo, size: Vector2.new(200,200), acidity: 0)
      @zone.light.sunlight.should eq [@zone.size.y - 1] * @zone.size.x

      @compost = Game.item_code('ground/earth-compost')
    end

    it "should query the surface for compost" do
      growth = ZoneKernel::Growth.new(@zone.kernel)
      [[5, 5], [6,5], [7,5]].each {|b| compost_up(*b)}

      growables = growth.growables.should =~ [[5,5,@compost,0,0], [6,5,@compost,0,0], [7,5,@compost,0,0]]
    end

    it "plant a new plant" do
      @zone.growth.stub(:should_grow?).and_return(true)

      [[5, 5], [6,5]].each {|b| compost_up(*b)}

      @zone.growth.step!
      @zone.peek(5, 4, FRONT)[1].should eq 0
      @zone.peek(6, 4, FRONT)[1].should eq 0

      possible_growth_items.should include @zone.peek(5, 4, FRONT)[0]
      possible_growth_items.should include @zone.peek(6, 4, FRONT)[0]
    end

    it "continue to grow a plant" do
      @zone.growth.stub(:should_grow?).and_return(true)

      [[5, 5], [6,5]].each {|b| compost_up(*b)}

      @zone.growth.step!
      @zone.growth.step!

      possible_growth_items.should include @zone.peek(5, 4, FRONT)[0]
      possible_growth_items.should include @zone.peek(6, 4, FRONT)[0]

      @zone.peek(5, 4, FRONT)[1].should eq 1
      @zone.peek(6, 4, FRONT)[1].should eq 1
    end
  end

  describe 'performance' do

    it 'should grow quickly' do
      @zone = with_a_zone(data_path: :deepworldhq, size: Vector2.new(2000, 600), acidity: 0)
      b = Benchmark.measure do
        @zone.growth.step! 100
      end
      b.real.should < 1.0
    end

  end

  def compost_up(x, y)
    @zone.update_block(nil, x, y, FRONT, @compost)
    @zone.peek(x, y, FRONT).should eq [@compost, 0]
  end

  def possible_growth_items(growable = 'ground/earth-compost', seed = 'air')
    items = YAML.load_file(File.expand_path('../../../models/dynamics/growth.yml', __FILE__))['biomes']['plain'][growable][seed].keys
    items.map{|i| Game.item_code i}
  end
end
