# An entrance or exit of an entity (npc/player) into the game world
class EntityStatusMessage < BaseMessage
  include EntityMessageHelper

  configure collection: true
  STATUS = {0 => :leaving, 1 => :entering, 2 => :dead, 3 => :revived}

  # entity_id: the id of the entity
  # ilk: the type of the entity (0 = player, 1 = ghost)
  # name: the name of the entity
  # datails: the appearance of the entity
  # status: entity's connection/living state (0 = leaving, 1 = entering, 2 = dead, 3 = revived)
  data_fields :entity_id, :ilk, :name, :status, :details

  # def should_send?(data, player)
  #   !(player.zone && player.zone.tutorial? && another_player?(player.zone, player, data[0]))
  # end

  def validate
    @errors = "Ilk cannot be blank unless status is 0" if @data.any?{ |d| d[1].blank? && d[3] != 0 }
  end

  def data_log
    nil
  end
end