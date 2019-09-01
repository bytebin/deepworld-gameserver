# Count number of item in world
class CountCommand < BaseCommand
  data_fields :item_name
  admin_required

  def execute
    case item_name
    when 'entities'
      alert "Found #{zone.npcs.size} entities"

    when 'entities_detailed'
      player.show_dialog [{
        'title' => 'Entities',
        'text' => zone.npcs.inject({}) { |hash,ent|
          hash[ent.config.name] ||= 0;
          hash[ent.config.name] += 1;
          hash
        }.to_a.sort_by{ |a| -a[1] }.map{ |a|
          "#{a[0]}: #{a[1]}"
        }.join("\n")
      }]

    when 'behave'
      alert "#{zone.ecosystem.last_behave_count} entities behaved last step"

    when 'mobs'
      alert "Found #{zone.npcs.count{ |npc| !npc.block }} mobs"

    when 'characters'
      alert "Found #{zone.characters.size} characters"

    else
      item = Game.item(item_name)
      if item && item.code > 0
        layer = { 'front' => FRONT, 'back' => BACK, 'liquid' => LIQUID, 'base' => BASE }[item.layer]
        count = zone.find_items(item.code, layer).size
        alert "Found #{count} #{item_name} in zone"
      else
        alert "Couldn't identify #{item_name}"
      end
    end
  end

end
