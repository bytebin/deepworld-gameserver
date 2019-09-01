module Items
  module WorldMachines
    class Base < Items::Base

      def use(params = {})
        if @player.owns_current_zone?
          show_dialog get_dialog('menu') do |resp|
            case resp.first
            when 'configure'
              dialog = get_dialog('configure')
              show_dialog dialog do |resp|
                vals = Dialog.values_hash(dialog, resp, @player)
                vals['position'] = [@position.x, @position.y]

                @zone.update "machines_configured.#{dialog_type}" => vals do
                  @player.alert 'Configuration activated!'
                  update!
                end
              end
            when 'move'
              @player.placements.transmittable_block = @position
              @player.alert 'Place a beacon to move the machine. The machine\'s lower left corner will replace the beacon.'
            when 'dismantle'
              @player.alert 'World machines can not yet be dismantled, but this feature is coming soon!'
            else
              menu! resp.first
            end
          end
        else
          @player.alert "This machine can only be configured by a world owner."
        end
      end

      def show_dialog(cfg, &block)
        @player.show_dialog cfg do |resp|
          yield resp
        end
      end

      def get_dialog(subtype)
        dialog = Marshal.load(Marshal.dump(Game.config.dialogs.world_machines[dialog_type][subtype]))

        # Remove sections that aren't in machine's power level
        dialog.sections.reject!{ |s| s.power && s.power > (@item.power || 1) }

        # Add current values
        if @zone.machines_configured[dialog_type]
          dialog.sections.each do |s|
            if s.input && s.input['key']
              if val = @zone.machines_configured[dialog_type][s.input['key']]
                s.value = val
              end
            end
          end
        end

        dialog
      end

      def dialog_type
        raise "Define me!"
      end

      def menu!(option)
        # Non-generic menu options
      end

      def update!
        # Called after dialog updated
      end

    end
  end
end