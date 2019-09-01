class DrainCommand < BaseCommand
  include WorldCommandHelpers
  throttle 2, 2.0

  def execute
    range = 5
    xMin = [player.position.x.to_i - range, 0].max
    xMax = [player.position.x.to_i + range, zone.size.x - 1].min
    yMin = [player.position.y.to_i - range, 0].max
    yMax = [player.position.y.to_i + range, zone.size.y - 1].min
    (xMin..xMax).each do |x|
      (yMin..yMax).each do |y|
        zone.update_block nil, x, y, LIQUID, 0, 0 if zone.peek(x, y, LIQUID)[0] != 0
      end
    end
    alert "Drained!"
  end

  def validate
    run_if_valid :validate_owner
  end

  def fail
    alert @errors.join(', ')
  end

end
