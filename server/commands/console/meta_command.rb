# Change meta block
class MetaCommand < BaseCommand
  data_fields :x, :y, :field, :value
  admin_required

  def execute
    @x = @x.to_i
    @y = @y.to_i
    meta = zone.get_meta_block(x, y) || zone.set_meta_block(x, y, Game.item(zone.peek(x, y, FRONT)[0]))

    case field
    when 'player'
      Player.where(name_downcase: value.downcase).fields([:_id]).callbacks(false).first do |pl|
        if pl
          meta.player_id = pl.id.to_s
          alert "Updated player '#{value}' on meta block #{x}x#{y}"
          zone.send_meta_block_message meta
        else
          alert "Unknown player '#{value}'"
        end
      end
    else
      meta[field] = value
      alert "Updated '#{field}' on meta block #{x}x#{y}"
      zone.send_meta_block_message meta
    end
  end

  def validate
    error_and_notify "Required params: x, y, field, value" unless x =~ /\d+/ && y =~ /\d+/ && field.is_a?(String) && value
  end

end
