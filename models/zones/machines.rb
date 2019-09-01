module Zones
  module Machines

    def machine_description(machine)
      case machine.to_sym
      when :geck then 'purifier'
      when :composter then 'composter'
      when :expiator then 'expiator'
      when :recycler then 'recycler'
      end
    end

    def machine_parts_count(machine)
      case machine.to_sym
      when :geck then 8
      when :composter then 6
      when :expiator then 8
      when :recycler then 6
      end
    end

    def machine_parts_discovered(machine)
      @machines_discovered[machine] || []
    end

    def machine_parts_discovered_count(machine)
      machine_parts_discovered(machine).size
    end

    def discover_machine_part!(machine, part, player = nil)
      @machines_discovered[machine] ||= []
      @machines_discovered[machine] << part
      @machines_discovered[machine].uniq!

      Items::MetaChange.new(player, item: Game.item(part)).use!
    end

    def machines_status_message(player)
      data = [[:geck, 'p'], [:composter, 'c'], [:expiator, 'e'], [:recycler, 'r']].inject({}) do |hash, machine|
        parts = machine_parts_discovered(machine.first)
        hash[machine.last] = parts if parts.size > 0
        hash
      end

      if player.v3?
        ZoneStatusMessage.new([data])
      elsif player.client_version?('2.1.0')
        ZoneStatusMessage.new('machines' => data)
      else
        ZoneStatusMessage.new(data)
      end
    end

    def send_machines_status_message_to_all
      players.each do |pl|
        pl.queue_message machines_status_message(pl)
      end
    end


    # ===== Purifier ===== #

    def purifier_complete?
      machine_parts_discovered_count(:geck) >= 8
    end

    def purifier_active?
      purifier_complete?
    end

    def process_purifier(delta)
      if @geck_meta_block and purifier_complete?
        active = self.purifier_active?

        if active
          change = -delta/60.0/60.0/24.0/3.0 # 3 days
          @acidity = (@acidity + change).clamp(0, 1.0)
        end

        current_mod = peek(@geck_meta_block.x, @geck_meta_block.y, FRONT)[1]
        mod = active ? 2 : 1

        update_block nil, @geck_meta_block.x, @geck_meta_block.y, FRONT, @geck_meta_block.item.code, mod if mod != current_mod
      end
    end


    # ===== Composter ===== #

    def composter_complete?
      machine_parts_discovered_count(:composter) >= 6
    end

    def composter_active?
      purifier_complete?
    end



    # ===== Recycler ===== #

    def recycler_complete?
      machine_parts_discovered_count(:recycler) >= 6
    end

    def recycler_active?
      recycler_complete?
    end


    # ===== Expiator ===== #

    def expiate_ghosts(player, ghosts)
      if ghosts
        # Kill ghosts
        ghosts.each do |ghost|
          ghost.set_details '!' => 'v'
          remove_entity ghost
        end

        # Remove hell dishes
        hell_dishes = meta_blocks_with_item(Game.item_code('hell/dish')).random(ghosts.size)
        [*hell_dishes].each do |dish|
          update_block nil, dish.x, dish.y, FRONT, 0
        end

        # Achievement
        Achievements::DeliveranceAchievement.new.check(player, ghosts.size)
      end
    end


    # ===== World Machines ===== #

    def machine_level(type, key)
      if @machines_configured[type]
        @machines_configured[type][key]
      end
    end

    def machine_exists?(player, type)
      @machines_configured[type].present? || player.admin?
    end

    def machine_setting(type, key)
      @machines_configured[type].present? ?
        @machines_configured[type][key] :
        nil
    end

    def machine_allows?(player, type, key)
      if level = machine_level(type, key)
        player.owns_current_zone? ||
          (level == 1 && player.belongs_to_current_zone?) ||
          level == 2
      else
        player.admin?
      end
    end

  end
end