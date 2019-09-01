require File.join(File.dirname(__FILE__), 'servant_place')

module Behavior
  class ServantFill < Behavior::ServantPlace

    def behave(params = {})
      extrapolate_directed_blocks
      place_after_interval!
      Rubyhave::SUCCESS
    end

    def extrapolate_directed_blocks
      t = last_directed_at
      if Ecosystem.time > t + 1.second && t != @last_extrapolated_at
        @last_extrapolated_at = t

        if blocks = get(:directed_blocks)
          # Find min and max to form rectangle
          min = blocks.first.dup
          max = blocks.first.dup
          blocks.each do |block|
            min.x = [min.x, block.x].min
            min.y = [min.y, block.y].min
            max.x = [max.x, block.x].max
            max.y = [max.y, block.y].max
          end

          blocks.clear

          # If rectangle is too large, alert user it will be smaller
          if (max.x - min.x) * (max.y - min.y) > 2000
            get(:owner).alert "Butlers can only fill up to 2000 blocks at a time."
            return
          end

          # Extrapolate
          (min.y..max.y).each do |y|
            xs = (min.x..max.x).to_a
            xs.reverse! if y % 2 == 1
            xs.map { |x| blocks << Vector2[x, y] }
          end
        end
      end
    end

    def can_behave?(params = {})
      can_reach_directed_target? && Ecosystem.time > last_directed_at + 1.second
    end

    def last_directed_at
      get(:last_directed_at) || Ecosystem.time
    end

  end
end
