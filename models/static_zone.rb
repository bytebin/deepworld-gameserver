class StaticZone
  def initialize(zone)
    @zone = zone
    initialize_item_limits(zone.static_type)
    set_weather
    set_daytime
  end

  def name
    @name ||= @zone.static_type.titleize
  end

  def inventory_allowed(player, item_id, requested_amount)
    item_id.to_s

    limit = @item_limits[item_id] || 0
    if limit == 0
      return limit
    else
      return [limit - player.inv.quantity(item_id), requested_amount].min
    end
  end

  private

  def initialize_item_limits(key)
    data = YAML.load_file(File.expand_path('../../config/static_item_limits.yml', __FILE__))[key]
    @item_limits = data.nil? ? {} : Game.code_keys(data)
  end

  def set_weather
    if @zone.tutorial?
      @zone.weather.rain = Dynamics::Weather::Rain.new(1_000_000, 0.5)
    end
  end

  def set_daytime
    if @zone.tutorial?
      @zone.daytime_cycle = 999_999_999
    end
  end
end