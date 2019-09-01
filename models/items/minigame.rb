module Items
  class Minigame < Base

    def use(params = {})
      if minigame = @zone.minigame_at_position(@position)
        minigame.use @player, params

      else
        # Custom minigames
        if @item.use.minigame.type == "custom"
          begin_custom_minigame

        # If start dialog, get input from player and start via dialog (unless options have been supplied)
        elsif @item.use.minigame.start_dialog && !params[:options]
          @player.show_dialog @item.use.minigame.start_dialog, true, { type: :minigame, position: @position, item: @item }

        # Otherwise start directly (unless item is gone)
        else
          if @zone.peek(@position.x, @position.y, FRONT)[0] == @item.code
            @zone.start_minigame(@item.use.minigame.type, @position, @player, params[:options])
          end
        end
      end
    end

    def begin_custom_minigame
      @player.show_dialog Game.config.dialogs.minigames.custom.create, true do |creation|
        case creation[0]
        when "customize"
          @player.show_dialog Game.config.dialogs.minigames.custom.customize, true do |customization, customization_hash|
            config = customization_hash
            @player.show_dialog Game.config.dialogs.minigames.custom.customize_options, true do |customization_options, customization_options_hash|
              config.merge! customization_options_hash
              confirm_custom_minigame config
            end
          end
        when "last"
          if code = @meta["mini"]
            copy_custom_minigame code
          else
            @player.alert "No previous minigame at this location!"
          end
        when "copy"
          @player.show_dialog Game.config.dialogs.minigames.custom.copy_existing, true do |copy_existing|
            code = copy_existing[0].downcase
            copy_custom_minigame code
          end
        end
      end
    end

    def copy_custom_minigame(code)
      MinigameRecord.where(code: code).first do |record|
        if record
          config = { "copy_from" => record }
          confirm_custom_minigame config
        else
          @player.alert "Cannot find minigame with code #{code}."
        end
      end
    end

    def confirm_custom_minigame(config)
      dialog = Marshal.load(Marshal.dump(Game.config.dialogs.minigames.custom.confirm))
      dialog.sections += minigame_description_sections(config)

      @player.show_dialog dialog, true do |confirm|
        minigame = @zone.start_minigame(@item.use.minigame.type, @position, @player, (params[:options] || {}).merge(config))
      end
    end

    def minigame_description_sections(config)
      minigame = Minigames::Custom.new(nil, nil, nil, config)

      ["Scoring: #{minigame.scoring_event.to_s.titleize}",
       "Range: #{minigame.range == 9999 ? 'World' : minigame.range.to_s + ' blocks'}",
       "Countdown Duration: #{minigame.countdown_duration.to_period(false, false)}",
       "Duration: #{minigame.duration.to_period(false, false)}",
       "Tool Restriction: #{minigame.tool_restriction > 0 ? Game.item(minigame.tool_restriction).try(:title) || 'Unknown' : 'None'}",
       "Block Restriction: #{minigame.block_restriction > 0 ? Game.item(minigame.block_restriction).try(:title) || 'Unknown' : 'None'}",
       "Mob Restriction: #{minigame.entity_restriction > 0 ? Game.entity_by_code(minigame.entity_restriction).try(:title) || 'Unknown' : 'None'}",
       "Max Deaths: #{minigame.max_deaths > 0 ? minigame.max_deaths : 'No Limit'}",
       "Natural: #{minigame.natural.titleize}"
      ].map{ |text| { text: text } }
    end

  end
end
