class EntityUseCommand < BaseCommand
  data_fields :entity_id, :data

  def execute
    if zone.ecosystem && @entity = zone.entities[@entity_id]
      # Interacting with player
      if @entity.is_a?(Player)
        if data.is_a?(Array) && data.size == 2
          case data[0]
          when 'trade'
            # Start or continue trade
            player.trade_item(@entity, data[1].to_i)
          end
        end

      # Interacting with NPC
      else
        @entity.interact player, :interact, @data
      end
    end
  end

  def validate
    @errors << "Entity ID must be a number" unless @entity_id.is_a?(Fixnum)
  end

end