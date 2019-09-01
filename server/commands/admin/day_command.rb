class DayCommand < BaseCommand
  admin_required
  data_fields :daytime

  def execute
    zone.daytime = daytime
    zone.send_zone_status
    alert "Daytime set to #{daytime.round(2)}"
  end

  def validate
    err = "Daytime must be a number between 0 and 1"
    unless (daytime.is_a?(Numeric) and (0..1).include?(daytime))
      @errors << err
      alert err
    end
  end
end