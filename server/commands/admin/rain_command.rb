class RainCommand < BaseCommand
  admin_required
  data_fields :rain

  def execute
    duration = 5.0
    zone.weather.rain = Dynamics::Weather::Rain.new(duration, @rain)
    zone.weather.step! duration*60
    zone.send_zone_status
  end

  def validate
    err = "Rain must be a number between 0 and 1"
    unless (rain.is_a?(Numeric) and (0..1).include?(rain))
      @errors << err
      alert err
    end
  end
end