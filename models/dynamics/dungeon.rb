module Dynamics
  class DungeonMaster

    attr_reader :dungeons

    def initialize(zone)
      @zone = zone
      @dungeons = {}
      @dungeons_by_id = {}

      if @zone.version >= 17
        index!
      else
        legacy_index!
      end
    end

    def dungeon(index)
      index = @zone.block_index(index[0], index[1]) if index.is_a?(Array)
      index = @zone.block_index(index.x, index.y) if index.is_a?(Vector2)
      @dungeons[index]
    end

    def destroy_guard_block!(meta, destroyer)
      if dun = dungeon(meta.index)
        dun.destroy_guard_block! meta, destroyer
      end
    end

    # Newer zones indexed based on dungeon ID
    def index!
      @zone.meta_blocks_with_use('guard').each do |meta|
        if dungeon_id = meta['@']
          dungeon = @dungeons_by_id[dungeon_id] ||= Dungeon.new(@zone)
          dungeon.add_guard_block meta
          @dungeons[meta.index] = dungeon
        end
      end

      @zone.meta_blocks_with_use('container').select{ |m| m['$'] }.each do |meta|
        if dungeon_id = meta['@']
          if dungeon = @dungeons_by_id[dungeon_id]
            dungeon.add_loot_block meta
          end
        end
      end
    end

    # Older zones are indexed by finding correlating guard blocks (and loot is not indexed)
    def legacy_index!
      @zone.meta_blocks_with_use('guard').each do |meta|
        # Check for dungeons matching "other" guard items of this meta block,
        # and create/update dungeon accordingly
        if d = (meta['o'] || []).find{ |oo| dungeon(oo) }
          dun = dungeon(d)
          dun.add_guard_block(meta)
          @dungeons[meta.index] = dun
        else
          dun = Dungeon.new(@zone, meta)
          @dungeons[meta.index] = dun
        end
      end
    end

  end

  class Dungeon

    attr_reader :guard_blocks, :loot

    def initialize(zone, meta = nil)
      @zone = zone
      @guard_blocks = []
      @loot_blocks = []
      add_guard_block meta if meta
    end

    def add_guard_block(meta)
      @guard_blocks << meta
    end

    def add_loot_block(meta)
      @loot_blocks << meta
    end

    def destroy_guard_block!(meta, destroyer)
      @guard_blocks.delete meta

      # Update loot blocks
      @loot_blocks.each do |loot|
        # Mark first dungeon raiding - loot will be unlocked automatically after enough time
        loot['dt'] ||= Time.now.to_i

        # Mark player raiding counts - loot will be unlocked to raiders immediately
        loot['dp'] ||= {}
        loot['dp'][destroyer.id.to_s] ||= 0
        loot['dp'][destroyer.id.to_s] += 1
      end

      # Finish dungeon raid if no guard blocks left
      if @guard_blocks.blank?
        complete! destroyer
      end
    end

    def complete!(completer)
      Achievements::RaiderAchievement.new.check(completer)
      completer.notify 'You raided a dungeon!', 10
      completer.notify_peers "#{completer.name} raided a dungeon.", 11
      completer.add_xp :dungeon_raid
      completer.event! :raid
    end

  end
end