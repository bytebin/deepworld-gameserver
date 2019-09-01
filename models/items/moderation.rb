module Items
  class Moderation < Base

    def use(params = {})
      if @player.owns_current_zone?
        @player.confirm_with_dialog "Remove sign?" do
          # Ensure same item
          if @zone.peek(@position.x, @position.y, FRONT)[0] == @item.code
            @zone.update_block nil, @position.x, @position.y, FRONT, 0
            @player.alert "Sign removed."
          end
        end
      end
    end

  end
end