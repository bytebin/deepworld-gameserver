class SpatialHash

  # Item interface
  # - spatial_position
  # - spatial_type

  attr_reader :chunks

  def initialize(chunk_size, max_size, error_proc)
    @chunk_size = chunk_size
    @chunk_size_f = Vector2[chunk_size.x.to_f, chunk_size.y.to_f]
    @max_size = max_size
    @chunk_count = Vector2[(max_size.x / chunk_size.x.to_f).ceil.to_i, (max_size.y / chunk_size.y.to_f).ceil.to_i]
    @chunks = @chunk_count.y.times.map{ |y| @chunk_count.x.times.map{ |x| Chunk.new(x, y) }}
    @chunk_refs = {}
    @error_proc = error_proc
  end

  def <<(item)
    add item
  end

  def add(item)
    if existing_ch = @chunk_refs[item]
      existing_ch.delete item
    end

    if ch = chunk_for(item.spatial_position.x, item.spatial_position.y)
      ch << item
      @chunk_refs[item] = ch
    else
      error! "Can't add item: No chunk for #{item.spatial_position}"
    end
    item
  end

  def delete(item)
    if ch = @chunk_refs[item]
      ch.delete item
      @chunk_refs.delete item
    else
      error! "Can't delete item: no chunk for #{item}"
    end
    item
  end

  def chunk_at(x, y)
    return nil if x < 0 || y < 0
    @chunks[y] ? @chunks[y][x] : nil
  end

  def chunk_for(world_x, world_y)
    ch_x = (world_x / @chunk_size.x).to_i
    ch_y = (world_y / @chunk_size.y).to_i
    @chunks[ch_y] ? @chunks[ch_y][ch_x] : nil
  end

  def reindex
    errors = []
    @chunk_refs.values.each do |ch|
      ch.clear
    end
    @chunk_refs.keys.dup.each do |item|
      begin
        add item
      rescue
        errors << $1
      end
    end
    error! "#{errors.size} item(s) couldn't be reindexed in spatial hash" if errors.present?
  end

  def items
    @chunk_refs.keys
  end

  def items_near(position, distance, exact = true, type = nil)
    items = []
    steps_x = (distance / @chunk_size_f.x).ceil.to_i
    steps_y = (distance / @chunk_size_f.y).ceil.to_i
    chunk_origin_x = (position.x / @chunk_size.x).to_i
    chunk_origin_y = (position.y / @chunk_size.y).to_i
    (chunk_origin_x-steps_x..chunk_origin_x+steps_x).each do |x|
      (chunk_origin_y-steps_y..chunk_origin_y+steps_y).each do |y|
        if chunk = chunk_at(x, y)
          chunk.contents.each do |i|
            if (type ? i.spatial_type == type : true) &&
              (exact ? Math.within_range?(position, i.spatial_position, distance) : true )
              items << i
            end
          end
        end
      end
    end
    items
  end

  def items_near_fullsearch(position, distance, type = nil)
    @chunk_refs.keys.select { |item| Math.within_range?(position, item.spatial_position, distance) && (!type || type == item.spatial_type) }
  end

  def error!(err)
    @error_proc.call err if @error_proc
  end


  class Chunk

    attr_reader :x, :y, :contents

    def initialize(x, y)
      @x = x
      @y = y
      @contents = []
    end

    def <<(item)
      add item
    end

    def add(item)
      @contents << item
    end

    def delete(item)
      @contents.delete item
    end

    def clear
      @contents.clear
    end

    def inspect
      to_s
    end

    def origin
      Vector2[@x, @y]
    end

    def to_s
      "<Chunk #{x}x#{y}>"
    end

  end

end