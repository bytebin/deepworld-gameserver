module Items
  class TargetTeleport < Base

    def use(params = {})
      pos = nil
      if @meta['px'] && @meta['px'] =~ /\d+[ew]/ && @meta['py'] && @meta['py'] =~ /\-?\d+/
        pos = Vector2[@meta['px'].to_i * (@meta['px'] =~ /w/ ? -1 : 1), @meta['py'].to_i]
      end

      # If zone present, ask player if they want to go
      if @meta['pz'].present?
        Zone.where(name: @meta['pz']).callbacks(false).first do |z|
          if z
            @player.show_dialog({ 'sections' => [{ 'text' => "Teleport to world '#{z.name}'?"}], 'actions' => 'yesno' }, true) do
              @player.send_to z.id, false, pos.present? ? z.normalized_position(pos) : nil
            end
          else
            player.alert "Cannot locate world '#{@meta['pz']}', please recalibrate."
          end
        end

      # Just position
      else
        if normalized_pos = @zone.normalized_position(pos)
          @player.teleport! normalized_pos
        else
          player.alert "Cannot locate destination, please recalibrate."
        end
      end
    end

  end
end
