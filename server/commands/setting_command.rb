class SettingCommand < BaseCommand
  data_fields :key, :value

  def execute
    update_database = key == 'visibility'
    player.update_setting key, value, update_database
  end

  def validate
    allowed_settings = {
      'visibility' => [0, 1, 2],
      'pushMessages' => [0, 1],
      'playerSounds' => [0, 1],
      'lootPreference' => [0, 1]
    }

    if allowed_settings[key]
      @value = @value.to_i if allowed_settings[key][0].is_a?(Fixnum)
      @errors << "Invalid setting" unless allowed_settings[key].include?(value)
    elsif key == 'hotbar_presets'
      @errors << "Invalid setting" unless value.is_a?(Array) && value.flatten.size <= 200 && value.flatten.all?{ |v| v.is_a?(Fixnum) }
    else
      @errors << "Invalid setting"
    end
  end
end