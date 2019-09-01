class MetaBlock

  # @data is persisted data
  # @stash is ephemeral data

  attr_reader :zone, :index, :position, :position_array
  attr_accessor :item, :player_id, :data

  def initialize(zone, index, data)
    @zone = zone
    @index = index.to_i

    @item = data.delete('i')

    @item = Game.item(@item) unless @item.is_a?(Hash)

    @player_id = data.delete('p')
    @data = data
    @data.merge! @item.metadata if @item && @item.metadata
    @stash = {}

    @position = Vector2[x, y]
    @position_array = [x, y]
  end

  def [](key)
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
  end

  def stash(key)
    @stash[key]
  end

  def stash!(key, value)
    @stash[key] = value
  end

  def x
    @index % @zone.size.x
  end

  def y
    @index / @zone.size.x
  end

  def peek(layer)
    @zone.peek(x, y, layer)
  end

  def global?
    @item.meta == 'global'
  end

  def local?
    @item.meta == 'local'
  end

  def hidden?
    @item.meta == 'hidden'
  end

  def special_item?
    self.special_item.present?
  end

  def use?(use_type)
    !@item.use[use_type].nil?
  end

  def player?(player = nil)
    player ? @player_id == player.id.to_s : @player_id.present?
  end

  def player_or_followee?(player = nil)
    player ? @player_id == player.id.to_s || player.followees.include?(player.id) : @player_id.present?
  end

  def get_player
    @player_id ? @zone.find_player_by_id(@player_id) : nil
  end

  def field
    item.field || (item.field_meta && self[item.field_meta] ? 1 : 0)
  end

  def reindex
    zone.reindex_meta_block self
  end


  # Locks / keys

  def locked?
    self.key.present?
  end

  def key
    @data['k']
  end

  def unlock!
    @data.delete 'k'
  end




  def contents?
    false
  end

  def special_item
    @data['$']
  end

  def clear!
    # Delete any associated docs
    if @data['landmark_id']
      Landmark.collection.remove({ '_id' => BSON::ObjectId(@data['landmark_id']) })
    end
  end



  # ===== Links ===== #

  def guardians
    @data['!']
  end

  def remove_guard(entity_code)
    if guardians
      idx = guardians.index(entity_code)
      guardians.delete_at(idx) if idx
    end

    if item.spawner
      @zone.ecosystem.schedule_spawner entity_code, position
    end
  end

  def others
    @data['o']
  end


  def inspect
    "<MetaBlock #{self.x}x#{self.y} #{@index}, item #{@item.code}, player #{@player_id || 'nil'}, data #{@data}>"
  end


  # ===== Serialization ===== #

  def self.unpack(zone, data)
    return {} unless data

    data.inject({}) do |hash, block_data|
      hash[block_data.first.to_i] = MetaBlock.new(zone, block_data.first.to_s, block_data.last)
      hash
    end
  end

  def self.pack(meta_blocks)
    return {} unless meta_blocks

    meta_blocks.inject({}) do |hash, block|
      hash[block.first.to_s] = block.last.message_meta_data
      hash
    end
  end

  def message_data(client = false)
    [@index % @zone.size.x, @index / @zone.size.x, message_meta_data(client)]
  end

  def message_meta_data(client = false)
    d = { 'i' => item.try(:code) }.merge(@data)
    d['p'] = player_id if player_id

    if client
      d.except('v', 'vn', 'vj')
    else
      d
    end
  end

end