# The appearance of an entity has changed, ie shirt changed, item held
class EntityChangeMessage < BaseMessage
  configure collection: true
  data_fields :entity_id, :details

  def data_log
    nil
  end
end
