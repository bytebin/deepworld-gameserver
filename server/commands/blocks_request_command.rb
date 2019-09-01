# Send chunks back based on chunk indexes requested (subject to distance/admin validation)
# indexes: array of chunk indexes

class BlocksRequestCommand < BaseCommand
  data_fields :indexes

  def execute
    # TODO: Admin lockdown
    benchmark = Benchmark.measure do

      player.add_active_indexes indexes
      chunk_data = zone.chunk_data(indexes)

      if meta = player.zone.meta_blocks_for_chunks(indexes)
        player.queue_message meta
      end
      player.queue_message LightMessage.message_for_indexes(player.zone, indexes)
      player.queue_message BlocksMessage.new(chunk_data)
    end

    Game.add_benchmark :chunks_request, benchmark.real
  end

  def validate
    if Deepworld::Env.development?
      unless active_admin?
        # Don't allow chunks > 100 blocks away to be requested
        @indexes.reject! do |idx|
          position = Chunk.get_origin(zone, idx) + Vector2[10, 10]
          distance = (position - player.position).magnitude
          distance = [distance, (position - player.teleport_position).magnitude].min if player.teleport_position
          distance > 180
        end
      end
    end
  end

  def data_log
    nil
  end
end