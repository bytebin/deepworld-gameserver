module Zones
  module Exploration

    def add_area_explored(player, position)
      return if Deepworld::Env.production? && player.admin

      idx = chunk_index(position.x.to_i, position.y.to_i)
      if @chunks_explored[idx]
        false
      else
        @chunks_explored[idx] = true
        @chunks_explored_count += 1

        player.queue_peer_messages ZoneExploredMessage.new([idx])
        true
      end
    end

    def area_explored?(position)
      idx = chunk_index(position.x.to_i, position.y.to_i)
      idx && !!@chunks_explored[idx]
    end

    def percent_explored
      chunk_count = (size[0] / chunk_size[0]) * (size[1] / chunk_size[1])
      (chunks_explored_count || 0) / chunk_count.to_f
    end

  end
end