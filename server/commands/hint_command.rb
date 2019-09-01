class HintCommand < BaseCommand
  data_fields :key

  def execute
    player.ignore_hint @key
  end

  def validate
    @errors << "Must be a string" unless @key.is_a?(String)
  end

end