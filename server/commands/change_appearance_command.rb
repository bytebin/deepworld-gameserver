class ChangeAppearanceCommand < BaseCommand
  data_fields :changes

  def execute
    if changes
      if meta = changes['meta']
        if meta == 'randomize'
          player.randomize_appearance!

        elsif dialog = Game.config.wardrobe_panel.dialogs[meta]
          player.show_dialog({
            'sections' => [{ 'input' => dialog }],
            'target' => 'appearance',
            'alignment' => 'left'
          })
        end
      else
        changes.each_pair do |key, value|
          player.appearance[key] = value
          player.event! :appearance, Game.item(value)
        end
      end

      msg = EntityStatusMessage.new([player.status])
      if zone.tutorial?
        player.queue_message msg
      else
        zone.queue_message msg
      end
    end
  end

  def validate
    if changes
      changes.each_pair do |key, value|
        next if key == 'meta'

        if Game.config.wardrobe.has_key?(key)
          if key[-1] == '*'
            category = {'c*' => 'skin-color', 'h*' => 'hair-color'}[key]
            colors = Game.config.wardrobe[category].dup
            colors += Game.config.wardrobe[category + '-bonus'] if player.has_bonus_appearance_colors?
            @errors << "Player does not have color #{value}" unless colors.include?(value)
          else
            item = Game.item(value)
            @errors << 'Player does not have wardrobe' unless item && (item.base || player.wardrobe.include?(value))
          end
        else
          @errors << 'Key does not exist'
        end
      end
    end
  end

end