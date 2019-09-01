module Zones
  module MetaBlocks

    META_BLOCK_INDEXES = [:field, :field_damage, :teleporter, :zone_teleporter, :collector, :steam, :plaque, :entity, :inhibitor, :crafting_helpers]

    def set_meta_block(x, y, item, player = nil, data = nil)
      idx = block_index(x, y)
      data ||= {}
      data['i'] = item
      data['p'] = player.id.to_s if player

      block = MetaBlock.new(self, idx, data)

      if item
        @meta_blocks[idx] = block
        index_meta_block idx, block
      else
        @meta_blocks.delete idx
        unindex_meta_block idx, block
      end

      send_meta_block_message block
      block
    end

    def get_meta_block(x, y)
      idx = block_index(x, y)
      @meta_blocks[idx]
    end

    def index_all_meta_blocks
      @indexed_meta_blocks = {}
      META_BLOCK_INDEXES.each{ |mbi| @indexed_meta_blocks[mbi] = {} }

      @meta_blocks.each_pair do |idx, block|
        index_meta_block idx, block
      end
    end

    def index_meta_block(idx, block)
      @indexed_meta_blocks[:field][idx] = block if block.item.field || (block.item.field_meta && block[block.item.field_meta])
      @indexed_meta_blocks[:field_damage][idx] = block if block.item.field_damage
      @indexed_meta_blocks[:teleporter][idx] = block if block.item.use['teleport']
      @indexed_meta_blocks[:zone_teleporter][idx] = block if block.item.use['zone teleport']
      @indexed_meta_blocks[:collector][idx] = block if block.item.group == 'collector'
      @indexed_meta_blocks[:inhibitor][idx] = block if block.item.group == 'inhibitor'
      @indexed_meta_blocks[:steam][idx] = block if block.item.group == 'steam'
      @indexed_meta_blocks[:plaque][idx] = block if block.item.group == 'plaque'
      @indexed_meta_blocks[:entity][idx] = block if block.item.entity
      @indexed_meta_blocks[:crafting_helpers][idx] = block if block.item.crafting_helper
    end

    def unindex_meta_block(idx, meta_block)
      META_BLOCK_INDEXES.each{ |mbi| @indexed_meta_blocks[mbi].delete idx }
    end

    def reindex_meta_block(meta_block)
      unindex_meta_block meta_block.index, meta_block
      index_meta_block meta_block.index, meta_block
    end

    def all_indexed_meta_blocks(index)
      @indexed_meta_blocks[index] ? @indexed_meta_blocks[index].values : []
    end

    def send_meta_block_message(meta_block)
      queue_message meta_blocks_message({ meta_block.index => meta_block })
    end

    def meta_blocks_message(meta)
      if meta and data = meta.map{ |idx, meta| meta.message_data(true) } and data.present?
        BlockMetaMessage.new data
      else
        nil
      end
    end

    def all_meta_blocks_message(player = nil)
      meta_blocks_message @meta_blocks.select{ |idx, meta| meta.global? || meta.player?(player) }
    end

    def meta_blocks_for_chunks(chunks)
      meta_blocks_message @meta_blocks.select{ |idx, meta| meta.local? and chunks.include?(chunk_index(idx % @size.x, idx / @size.x)) }
    end

    def meta_blocks_with_item(item_code)
      @meta_blocks.values.select{ |meta| meta.item.code == item_code }
    end

    def meta_blocks_count(item_code)
      @meta_blocks.values.count{ |meta| meta.item.code == item_code }
    end

    def protectors_count
      @meta_blocks.values.count{ |meta| meta.item.field && meta.item.field > 1 }
    end

    def meta_blocks_with_use(use)
      @meta_blocks.values.select{ |meta| meta.use?(use) }
    end

    def meta_blocks_with_player(player)
      @meta_blocks.values.select{ |meta| meta.player?(player) }
    end

    def meta_blocks_description
      @meta_blocks.map do |idx, block|
        special = block.special_item? ? Game.item(block.special_item).try(:id) : nil
        ["#{idx % @size.x}x#{idx / @size.x}: #{block.item.id} / #{special || block.data}", block.item.code]
      end.compact.sort_by{ |b| b.last }.map(&:first).join("\n")
    end

    def meta_blocks_within_range(origin, distance, item_code = nil, meta_block_index = nil)
      item_code_is_array = item_code.is_a?(Array)

      # Convert item names to codes if necessary
      item_code = item_code.map{ |i| Game.item_code(i) } if item_code_is_array && item_code.first.is_a?(String)

      # Check meta blocks within range
      if blocks = meta_block_index ? @indexed_meta_blocks[meta_block_index] : @meta_blocks
        blocks.select do |idx, block|
          Math.within_range?([idx.to_i % @size.x, idx.to_i / @size.x], origin, distance) &&
            (item_code.nil? || (item_code_is_array ? item_code.include?(block.item.code) : item_code == block.item.code))
        end
      else
        {}
      end
    end

  end
end
