# Console command: help for various things
class HelpCommand < BaseCommand
  optional_fields :key

  def execute
    case key
    when nil
      alert "No general help is available yet, sorry."

    when 'competition'
      dialog = [{ 'title' => 'Official Competition' }]
      Competition.sort(:created_at, -1).first do |competition|
        dialog << { 'text' => special_text("The current official competition is #{competition.name}.") }
        dialog << { 'text' => competition.description }

        if player.zone.competition
          item_code = Game.item_code('mechanical/dish-competition-25')
          mbs = zone.meta_blocks_with_item(item_code)
          if mb_player = mbs.find{ |mb| mb.player?(player) }
            dialog << { 'text' => "Your protector is at #{zone.position_description(mb_player.position, false)}." }

          elsif (player.zone.explored_percent || 0) >= 0.75
            mbs_available = mbs.reject{ |mb| mb.player? }.sort_by{ |mb| (mb.position - player.position).magnitude }
            if mbs_available.present?
              dialog << { 'text' => "The nearest claimable protector is at #{zone.position_description(mbs_available.first.position, false)}." }
            else
              dialog << { 'text' => 'All competition protectors are claimed.' }
            end
          else
            dialog << { 'text' => 'Once the world is 75% explored, this dialog will show the nearest claimable protector location.' }
          end
        else
          dialog << { 'text' => special_text('Visit one of the competition worlds for more information.') }
        end

        player.show_dialog dialog, false
      end

    else
      alert "No help available for #{key}."
    end
  end

  def special_text(text)
    if player.v3?
      "<color=#ffd95f>#{text}</color>"
    else
      text
    end
  end

end