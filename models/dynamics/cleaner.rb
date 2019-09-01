module Dynamics
  class Cleaner

    def initialize(zone)
      @zone = zone
      @earth = Game.item_code('ground/earth')
      @disintegrating_earth = Game.item_code('ground/earth-disintegrating')
    end

    def step!(delta_time)
      unless @chunks
        sky_chunk_count = (@zone.chunk_width * (@zone.surface_max / @zone.chunk_size.y))
        @chunks = (0..sky_chunk_count)
      end

      Game.add_benchmark :block_cleaner do
        if chunk_idx = @chunks.random.to_i
          clean! chunk_idx
        end
      end
    end

    def clean!(chunk_idx)
      if @earth.present? && @disintegrating_earth.present?
        chunk = @zone.get_chunk(chunk_idx)

        # Blow away dug blocks
        chunk.query(0, nil, @disintegrating_earth).each do |block|
          @zone.update_block nil, block[0], block[1], FRONT, 0
        end

        # Kill turd blocks aboveground
        kill_blocks = @zone.kernel.below_query(chunk.index, false, @earth, 0)
        kill_blocks.each do |block|
          @zone.update_block nil, block[0], block[1], FRONT, @disintegrating_earth if rand < 0.5
        end
      end
    end

    def clean_all!
      @chunks.each{ |ch| clean! ch }
    end
  end
end