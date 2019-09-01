class HealthCommand < BaseCommand
  data_fields :amount, :attacker_id
  optional_fields :damage_type_code

  def execute
    if amount == 0 && player.entity_id == attacker_id
      player.die!
    elsif amount < player.health
      attacker = zone.entities[attacker_id] if attacker_id.to_i > 0
      player.damage! player.health - amount, damage_type_code, attacker, false
    else
      player.health = @amount
    end
  end

  def validate
    @amount = @amount.to_f / 1000.0

    # Validate the status
    @errors << "Player cannot increase their health" unless active_admin? || @amount <= player.health
  end
end
