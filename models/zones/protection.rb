module Zones
  module Protection

    def protectors_in_range(position, range_bump = 0, subset = nil)
      protectors = []
      subset ||= @indexed_meta_blocks[:field].values
      subset.each do |meta|
        if protector_in_field_range?(position, meta, range_bump) || protector_in_coverage?(position, meta, range_bump)
          protectors << meta
        end
      end
      protectors
    end

    def protector_in_field_range?(position, meta, range_bump)
      meta.field > 0 && (meta.field > 1 || position == meta.position) && Math.within_range?([meta.x, meta.y], position, meta.field + range_bump)
    end

    def protector_in_coverage?(position, meta, range_bump)
      if meta.item.field_coverage
        position.x >= meta.position.x - range_bump &&
          position.x < meta.position.x + meta.item.field_coverage[0] + range_bump &&
          position.y <= meta.position.y + range_bump &&
          position.y > meta.position.y - meta.item.field_coverage[1] - range_bump
      else
        false
      end
    end

    def block_protected?(position, entity = nil, prohibit_followees = false, protectors = nil, skip_teleporters = false, skip_self = false)
      # Verify zone protection level
      return true if entity.is_a?(Player) && protected_against?(entity)

      # Verify block field
      item = Game.item(peek(position.x, position.y, FRONT)[0])
      meta_block = get_meta_block(position.x, position.y)
      return true if item.field && (meta_block.nil? || !meta_block.player?(entity))

      # Verify force fields
      protectors ||= protectors_in_range(position)
      protectors.each do |meta|
        next if skip_self && meta.position == position
        meta_player = meta.player_id ? (BSON::ObjectId(meta.player_id) rescue nil) : nil
        allow_followees = prohibit_followees ? false : meta.data['t'] == 1
        next if skip_teleporters && (meta.item.use['teleport'] || meta.item.use['zone teleport'])
        return meta if !entity || (entity.is_a?(Player) && meta_player != entity.id && (!allow_followees || !entity.followers.include?(meta_player)))
      end

      false
    end

    # Global zone protection
    def protected_against?(player)
      level = @protection_level.to_i
      return false if level == 0
      return false if (self.owners.include?(player.id) || self.members.include?(player.id))

      if level < 10
        player.play_time < 1.day*level || player.level < 5*level
      else
        true
      end
    end

    def dish_will_overlap?(position, dish_range, entity)
      fields ||= @indexed_meta_blocks[:field].values
      fields.each do |meta|
        if Math.within_range?([meta.x, meta.y], position, meta.field + dish_range)
          return true unless meta.player_id.to_s == entity.id.to_s
        end
      end

      false
    end

  end
end