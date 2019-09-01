module Items
  class Guard < Base

    def destroy!
      # Give credit for destroying linked guard objects (e.g., an entire dungeon)
      @zone.dungeon_master.destroy_guard_block! @meta, @player
    end
  end
end