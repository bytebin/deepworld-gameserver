# Find nearest instance of item
class NearestCommand < BaseCommand
  data_fields :item_name
  admin_required

  def execute
    item = Game.item(item_name)
    if item && item.code > 0
      layer = { 'front' => FRONT, 'back' => BACK, 'liquid' => LIQUID, 'base' => BASE }[item.layer]
      blocks = zone.find_items(item.code, layer)
      if blocks.size > 0
        nearest = blocks.sort_by{ |b| (player.position - Vector2[b[0], b[1]]).sq_magnitude }
        alert "Nearest #{item_name} at: #{nearest.first(3).map{ |n| n.join('x') }.join(', ')} (#{nearest.size} total)"
      else
        alert "No #{item_name} found."
      end
    else
      alert "Couldn't identify item #{item_name}"
    end
  end

end
