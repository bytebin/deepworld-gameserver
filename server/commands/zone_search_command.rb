class ZoneSearchCommand < BaseCommand
  data_fields :type
  throttle 4, 1.0, true

  def execute
    searcher = ZoneSearcher.new(player)
    searcher.search(type)
  end
end
