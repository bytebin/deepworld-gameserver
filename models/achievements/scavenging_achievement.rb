module Achievements
  class ScavengingAchievement < BaseAchievement

    def check(player, command)
      progress_all player
    end


    # Forager

    def self.foraging_types
      @foraging_types ||= self.items_for_achievement('Forager')
    end

    def self.foraging_types_quantity(player)
      foraging_types.size
    end

    def self.foraging_types_discovered(player)
      (player.items_discovered_hash.keys & foraging_types).size
    end

    # Master Forager

    def self.master_foraging_types
      @master_foraging_types ||= self.items_for_achievement('Master Forager')
    end

    def self.master_foraging_types_quantity(player)
      master_foraging_types.size
    end

    def self.master_foraging_types_discovered(player)
      (player.items_discovered_hash.keys & master_foraging_types).size
    end

    # Horticulturalist

    def self.horticulturalist_types
      @horticulturalist_types ||= self.items_for_achievement('Horticulturalist')
    end

    def self.horticulturalist_types_quantity(player)
      horticulturalist_types.size
    end

    def self.horticulturalist_progress(player)
      horticulturalist_types.count{ |t| (player.items_discovered_hash[t] || 0) >= 10 }
    end

    # Master Horticulturalist

    def self.master_horticulturalist_types
      @master_horticulturalist_types ||= self.items_for_achievement('Master Horticulturalist')
    end

    def self.master_horticulturalist_types_quantity(player)
      master_horticulturalist_types.size
    end

    def self.master_horticulturalist_progress(player)
      master_horticulturalist_types.count{ |t| (player.items_discovered_hash[t] || 0) >= 10 }
    end

  end
end
