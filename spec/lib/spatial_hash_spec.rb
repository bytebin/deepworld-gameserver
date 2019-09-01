require 'spec_helper'

describe SpatialHash do

  class SpatialItem
    attr_accessor :spatial_type, :spatial_position

    def initialize(type, pos)
      @spatial_type = type
      @spatial_position = pos
    end

    def inspect
      "<#{@spatial_type} #{@spatial_position.x}x#{@spatial_position.y}>"
    end

    def to_s
      inspect
    end
  end

  before(:each) do
    @space = SpatialHash.new(Vector2[10, 10], Vector2[1000, 1000], Proc.new{ |err| raise err })
  end

  it 'should find items near another item' do
    a1 = @space << SpatialItem.new(:a, Vector2[295, 295])
    a2 = @space << SpatialItem.new(:a, Vector2[300, 300])
    a3 = @space << SpatialItem.new(:a, Vector2[305, 305])
    a4 = @space << SpatialItem.new(:a, Vector2[320, 320])
    a5 = @space << SpatialItem.new(:a, Vector2[400, 400])
    a6 = @space << SpatialItem.new(:a, Vector2[500, 500])
    b1 = @space << SpatialItem.new(:b, Vector2[300, 300])

    @space.items.should =~ [a1, a2, a3, a4, a5, a6, b1]
    @space.items_near(Vector2[305, 305], 20).should =~ [a1, a2, a3, b1]
    @space.items_near(Vector2[310, 310], 20).should =~ [a2, a3, a4, b1]
    @space.items_near(Vector2[305, 305], 200).should =~ [a1, a2, a3, a4, a5, b1]
    @space.items_near(Vector2[500, 500], 20).should =~ [a6]
    @space.items_near(Vector2[305, 305], 20, true, :b).should =~ [b1]
  end

  it 'should not find items that have been removed' do
    a1 = @space << SpatialItem.new(:a, Vector2[295, 295])
    @space.delete a1
    @space.items_near(Vector2[305, 305], 20).should =~ []
  end

  it 'should find moved items after a full reindex' do
    a1 = @space << SpatialItem.new(:a, Vector2[100, 100])

    @space.items_near(Vector2[300, 300], 20).should =~ []

    a1.spatial_position = Vector2[305, 305]
    @space.reindex
    @space.items_near(Vector2[300, 300], 20).should =~ [a1]
  end

  it 'should hopefully be faster' do
    num_tests = 3
    num_queries_per_test = 500
    num_queries_per_test *= 10 if ENV['ECHO']

    num_tests.times do |t|
      num_items = 500
      num_items *= 4 if ENV['ECHO']
      num_items.times do
        item = SpatialItem.new(:a, random_position)
        @space << item
      end

      max_range = [10, 50, 100][t]
      query_positions = num_queries_per_test.times.map{ random_position }
      query_ranges = num_queries_per_test.times.map{ random_range(max_range) }

      spatial_benchmark = Benchmark.measure do
        num_queries_per_test.times do |q|
          @space.reindex if q % 100 == 0
          @space.items_near(query_positions[q], query_ranges[q])
        end
      end

      inexact_spatial_benchmark = Benchmark.measure do
        num_queries_per_test.times do |q|
          @space.reindex if q % 100 == 0
          @space.items_near(query_positions[q], query_ranges[q], false)
        end
      end

      fullsearch_benchmark = Benchmark.measure do
        num_queries_per_test.times do |q|
          @space.items_near_fullsearch(query_positions[q], query_ranges[q])
        end
      end

      spatial_benchmark.real.should < fullsearch_benchmark.real

      if ENV['ECHO']
        puts "TEST ##{t+1} (max range #{max_range}):"
        puts "- Spatial (exact): #{(spatial_benchmark.real*1000).to_i}ms"
        puts "- Spatial (inexact): #{(inexact_spatial_benchmark.real*1000).to_i}ms"
        puts "- Spatial (fullsearch): #{(fullsearch_benchmark.real*1000).to_i}ms"
        puts "\n"
      end
    end
  end

  def random_position
    Vector2[(0..999).random, (0..999).random]
  end

  def random_range(max_range)
    (5..max_range).random
  end

end
