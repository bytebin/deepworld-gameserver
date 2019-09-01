# require 'ruby_vor'
# require 'rgl/adjacency'
# require 'rgl/prim'

module Gen
  class Compound

    attr_accessor :rooms, :delaunay

    class Room
      attr_accessor :rect, :tags

      def initialize(origin, size)
        @rect = Rect.new(origin.x, origin.y, size.x, size.y)
        @tags = []
      end

      def tagged?(tag)
        @tags.include?(tag)
      end
    end

    def initialize(options = {})
      @width = options[:width]
      @height = options[:height]
      @room_count = options[:room_count] || 100
      @min_room_size = options[:max_room_size] || Vector2[4, 4]
      @max_room_size = options[:max_room_size] || Vector2[12, 10]
      @small_room_percentage = 0.8

      @rooms = []

      create_rooms @room_count, @min_room_size, @max_room_size, @small_room_percentage
      remove_overlaps
      calculate_graphs
      normalize_quadrant
      display if ENV['GEN']
    end

    def rooms_sorted_by_distance_to_center
      @rooms.sort_by{ |r| r.rect.center.magnitude }
    end

    def random_pos(dist)
      Vector2[rand(dist) - dist*0.5, rand(dist) - dist*0.5].fixed
    end

    def random_small_size(min, max)
      Vector2[(min.x..min.x.lerp(max.x, 0.5)).random, (min.y..min.y.lerp(max.y, 0.5)).random].fixed
    end

    def random_large_size(min, max)
      Vector2[(max.x.lerp(max.x, 0.7)..max.x).random, (min.y.lerp(max.y, 0.5)..max.y).random].fixed
    end

    def create_rooms(count, min_size, max_size, small_room_percentage)
      count.times do
        pos = random_pos(max_size.x * 12)
        small = rand < small_room_percentage
        size = small ? random_small_size(min_size, max_size) : random_large_size(min_size, max_size)
        room = Room.new(pos, size)
        room.tags << :small if small
        @rooms << room
      end
      @rooms
    end

    def extents
      rect = @rooms[0].rect.dup
      @rooms[1..-1].each do |r|
        rect.union! r.rect
      end
      rect
    end

    def normalize_quadrant
      ex = extents
      @rooms.each do |r|
        r.rect.move! -ex.left, -ex.top
      end
    end

    def remove_overlaps
      iterations = 10

      b = Benchmark.measure do
        iterations.times do
          mvmts = []
          rooms = @rooms.randomized
          rooms.each do |r|
            mvmt = Vector2[0, 0]
            neighbors = rooms.select{ |r2| r != r2 && r.rect.collide_rect?(r2.rect, false) }
            if neighbors.present?
              neighbors.each do |neighbor|
                mvmt += (neighbor.rect.center - r.rect.center)
              end
              mvmt.x = -(mvmt.x / neighbors.size.to_f).to_i
              mvmt.y = -(mvmt.y / neighbors.size.to_f).to_i
            end
            mvmts << mvmt
          end

          rooms.each_with_index do |r, idx|
            r.rect.move! mvmts[idx].x, mvmts[idx].y
          end
        end
      end

      still_overlapping = @rooms.select{ |r| @rooms.any?{ |r2| r != r2 && r.rect.collide_rect?(r2.rect, false) }}
      @rooms -= still_overlapping

      p "Overlaps removed (#{(b.real * 1000).to_i}ms)"
    end

    def calculate_graphs
      @large_rooms = @rooms.reject{ |r| r.tagged?(:small) }
      pts = @large_rooms.map{ |r| RubyVor::Point.new(r.rect.center.x, r.rect.center.y) }
      @delaunay = RubyVor::VDDT::Computation.from_points(pts)
      pp @delaunay.minimum_spanning_tree

      @graph = RGL::AdjacencyGraph[@large_rooms.map{ |r| [r.rect.center.x, r.rect.center.y] }.flatten]
      @mst = @graph.prim_minimum_spanning_tree(Proc.new{ |i| 1 })
    end

    def display
      p "Rect: #{extents}"

      doc = Prawn::Document.new
      doc.text 'Deepworld Compound'

      @rooms.each do |r|
        doc.fill_color r.tagged?(:small) ? '882222' : 'cc6666'
        doc.fill_rectangle [r.rect.left, r.rect.top], r.rect.width, r.rect.height
      end

      # @mst.each_vertex do |v|
      #   @mst.each_adjacent(v) do |adj|
      #     p adj
      #   end
      # end

      pp @delaunay.nn_graph

      # @delaunay.nn_graph.first(5).each_with_index do |graph, idx|
      #   graph.each do |ri|
      #     r = @large_rooms[ri]
      #     str += %[<div class="room" style="background:##{colors[idx]};top:#{r.rect.top}em;left:#{r.rect.left}em;width:#{r.rect.width}em;height:#{r.rect.height}em"></div>]
      #   end
      # end

      #RubyVor::Visualizer.make_svg(@delaunay, name: 'tmp/compound.svg')
      #pp @delaunay.minimum_spanning_tree
      #RubyVor::Visualizer.make_svg(@delaunay, name: 'tmp/compound.svg', triangulation: false)

      filename = 'tmp/compound.pdf'
      doc.render_file filename
      p "Wrote HTML output to #{filename}."
    end

  end
end