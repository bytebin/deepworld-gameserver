class Chunk
  attr_reader :origin, :data, :height, :width, :index

  def initialize(zone, index)
    @zone = zone
    @index = index
    @width = @zone.chunk_size.x
    @height = @zone.chunk_size.y
  end

  def to_a(hide_owner = false)
    [x, y, @width, @height, data(hide_owner)]
  end

  def x
    origin.x
  end

  def y
    origin.y
  end

  def data(hide_owner = false)
    @data ||= @zone.kernel.chunk(@index, hide_owner)
  end

  def origin
    @origin ||= self.class.get_origin(@zone, @index)
  end

  # Query and receive an array of [x,y] arrays matching the parameters
  # * pass in nils to ignore this layer
  def query(base = nil, back = nil, front = nil, liquid = nil)
    @zone.kernel.block_query(@index, base, back, front, liquid)
  end

  class << self
    def get_origin(zone, index)
      chunk_width = (zone.size.x / zone.chunk_size.x).ceil

      y = (index / chunk_width).floor * zone.chunk_size.y
      x = (index % chunk_width) * zone.chunk_size.x

      Vector2.new(x, y)
    end

    def many(zone, indexes)
      indexes.uniq.map{ |i| new(zone, i) }
    end
  end
end