# Spawn an effect

class EffectCommand < BaseCommand
  admin_required
  data_fields :effect_type, :x, :y

  def execute
    zone.queue_message EffectMessage.new((x * Entity::POS_MULTIPLIER).to_i, (y * Entity::POS_MULTIPLIER).to_i, effect_type, 1)
  end
end