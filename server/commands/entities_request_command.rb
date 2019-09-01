class EntitiesRequestCommand < BaseCommand
  data_fields :entity_ids

  def execute
    statuses = entity_ids.inject([]) do |ents, entity_id|
      if player.tracking_entity?(entity_id)
        status = zone.entities[entity_id].try(&:status)
        ents << status if status.present?
      end
      ents
    end

    queue_message EntityStatusMessage.new(statuses) unless statuses.empty?
  end

end