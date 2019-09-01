module EntityMessageHelper
  def another_player?(zone, player, entity_id)
    zone.ecosystem.find(entity_id).player? && entity_id != player.entity_id
  end
end