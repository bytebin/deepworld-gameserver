class EffectMessage < BaseMessage
  data_fields :x, :y, :type, :quantity

  def data_log
    nil
  end
end