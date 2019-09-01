class ZoneChopSerializer
  attr_accessor :origin, :destination

  def initialize(zone, origin, destination)
    @zone = zone
    @origin = origin
    @destination = destination

    adjust_destination_for_chunk_size
  end

  def serialize
    [
      *size.to_a,
      @zone.chunk_size.x,
      @zone.chunk_size.y,
      chunks,
      MetaBlock.pack(meta_blocks)
    ]
  end

  def meta_blocks
    # Filter meta blocks to area, and adjust positions
    mb = @zone.meta_blocks.inject({}) do |h, (k, v)|
      if rect.contains? v.position
        # Offset the position and set the new index
        new_pos = v.position - @origin
        v.instance_variable_set :@index, new_pos.y * width + new_pos.x

        h[v.index] = v
      end
      h
    end
  end

  def chunks
    @zone.kernel.chopped_chunks(@origin.x, @origin.y, width, height)
  end

  def width
    @destination.x - @origin.x + 1
  end

  def height
    @destination.y - @origin.y + 1
  end

  def rect
    Rect[*@origin, width, height]
  end

  def size
    Vector2[width, height]
  end

  def adjust_destination_for_chunk_size
    x_chunk = @zone.chunk_size.x
    y_chunk = @zone.chunk_size.y

    if width % x_chunk > 0
      @destination.x = (((width / x_chunk).floor + 1) * x_chunk) + @origin.x - 1
    end

    if height % y_chunk > 0
      @destination.y = (((height / y_chunk).floor + 1) * y_chunk) + @origin.y - 1
    end

  end
end