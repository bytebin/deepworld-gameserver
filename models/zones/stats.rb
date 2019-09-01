module Zones
  module Stats

    def calc_explored_percent
      @chunks_explored_count / @chunk_count.to_f
    end

    def calc_development_level
      case calc_explored_percent
      when 0..0.333
        0
      when 0.333..0.667
        1
      else
        case @items_placed
        when 0..99999
          2
        when 100000..499999
          3
        when 500000..2500000
          4
        else
          5
        end
      end
    end

    def item_count(item, layer = FRONT)
      find_items(item.code, layer).size
    end

    def significant_item_counts
      {
        plaques: meta_blocks_count(Game.item('signs/plaque').code),
        landmarks: meta_blocks_count(Game.item('signs/plaque-landmark').code),
        teleporters: meta_blocks_count(Game.item('mechanical/teleporter').code),
        spawns: meta_blocks_count(Game.item('mechanical/zone-teleporter').code),
        protectors: protectors_count
      }
    end

  end
end