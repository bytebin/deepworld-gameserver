module Players
  module Xp

    LEVELS = [0, 0] # Other levels get aut-cached by #xp_for_level

    def use_xp?
      @xp_created_at ||= Time.new(2014, 9, 14)
      @version >= 4 || created_at > @xp_created_at
    end

    def grant_xp?(type)
      true
    end

    def add_xp(amount_or_type, msg = nil)
      if use_xp? && amount_or_type
        base_amount = amount_or_type.is_a?(Fixnum) ? amount_or_type : Xp.bonus(amount_or_type)
        amount = (base_amount * xp_multiplier).floor.to_i

        if amount != 0
          # Increment experience
          @xp += amount
          increment_daily_item amount
          send_xp_message amount, msg

          # Check for level up
          if can_level_up?
            if @xp >= Xp.xp_for_level(@level + 1)
              new_level = Xp.level_for_xp(@xp)
              points_awarded = new_level - @level

              update level: new_level, "level_ups.#{new_level}" => play_time.to_i do
                @points += points_awarded

                # Delay level up slightly in case achievement preceeded
                EM.add_timer(Deepworld::Env.test? ? 0 : 5.0) do
                  send_level_message new_level
                  notify_peers "#{@name} leveled up to level #{new_level}!", 11
                  queue_message StatMessage.new("points", @points)
                  event_message! 'hintOverlay', Game.config.hints.levelup if new_level == 2

                  # Skill instructions for level 2
                  if new_level == 2
                    EM.add_timer(Deepworld::Env.test? ? 0 : 5.0) do
                      queue_message EventMessage.new('uiHints', [
                        { 'message' => 'Pick a skill and click to upgrade!', 'highlight' => 200 },
                        { 'message' => 'Click to upgrade a skill', 'highlight' => 22 },
                        { 'message' => 'Click to open your profile', 'highlight' => 20 }
                      ])
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def can_level_up?
      @level < Xp.max_level
    end

    def send_xp_message(amount, msg)
      queue_message XpMessage.new(amount, @xp, msg)
    end

    def send_level_message(new_level)
      queue_message LevelMessage.new(new_level)
      queue_message EffectMessage.new(0, 0, 'levelup', 1)
    end

    def xp_multiplier
      base_xp_multiplier * timed_xp_multiplier
    end

    def base_xp_multiplier
      ranks = [@orders.values.count{|t|t >= 4}, @orders['moon'] || 0].max
      [premium? ? 1.05 : 1, 1.1, 1.2, 1.3, 1.4, 1.5][ranks] || 1
    end

    def timed_xp_multiplier
      if happening = Game.happening("xp_multiplier")
        happening["amount"].to_f.clamp(1.0, 3.0)
      else
        1.0
      end
    end


    # Values

    def self.xp_for_level(level)
      # (250*(n^2)) + (1750*n) - 2000
      unless LEVELS[level]
        LEVELS[level] = xp_for_level(level-1) + (2000 + 500*(level-1))
      end
      LEVELS[level]
    end

    def self.level_for_xp(xp)
      reversed_levels.find do |lv|
        xp >= xp_for_level(lv)
      end
    end

    def self.max_level
      Players::Skills::SKILLS.size * 7 + 1
    end

    def self.reversed_levels
      @reversed_levels ||= (1..max_level).to_a.reverse
    end


    def self.bonus(type)
      case type
      when :order
        5000
      when :achievement
        2000
      when :inhibitor
        500
      when :first_kill
        250
      when :first_mine, :first_craft
        150
      when :machine_part, :teleporter_repair, :dungeon_raid
        100
      when :undertaking, :deliverance
        25
      when :vote, :loot
        10
      when :plug, :trapping, :explore
        5
      when :craft
        1
      else
        0
      end
    end


    # Legacy

    def convert_for_xp!
      if @version == 3
        if @xp < achievements.size * Xp.bonus(:achievement)
          if xp_info = calculate_legacy_xp
            update version: 4,
              level: xp_info[:level],
              xp: xp_info[:xp],
              points: (@points || 0) + xp_info[:points] do |pl|

              color = "ff7733"
              show_dialog [
                { 'title' => "You're now level #{@level}!" },
                { 'text' => "Deepworld has switched to an XP leveling system. We've crunched the numbers and estimated your level based on your achievements and game stats. Going forward, you will level up normally." },
                { 'text' => "Level #{@level}", 'text-color' => color },
                { 'text' => "#{@xp} XP", 'text-color' => color },
                { 'text' => "#{xp_info[:points]} skill points added", 'text-color' => color }
              ]
            end
          end
        else
          update version: 4 do |pl|
            # Leave everything as-is
          end
        end

      elsif @version == 4
        extra_xp = 0
        achievements.keys.each do |ach|
          cfg = Game.config.achievements[ach]
          extra_xp += [((cfg.xp || 2000) - 2000), 0].max
        end

        @xp += extra_xp

        update version: 5, xp: @xp do |pl|
          if extra_xp > 0
            @hints_in_session << :login
            EM.add_timer(Deepworld::Env.test? ? 0 : 3.0) do
              msg = "Advanced achievements now award more XP. Since you have already earned some of those achievements, you've been granted XP retroactively:"
              xp_msg = "+#{extra_xp} XP"

              show_dialog [
                { 'title' => "Achievement XP Bonus" },
                { 'text' => msg },
                { 'text' => xp_msg, 'text-color' => 'ff7733' }
              ]

              Missive.deliver self, 'sys', msg + " " + xp_msg
            end
          end
        end
      end
    end

    def calculate_legacy_xp
      return nil if achievements.blank?

      begin
        min_xp = Xp.xp_for_level(achievements.size + 1)
        calculated_xp = achievements.size * Xp.bonus(:achievement) +
          (orders.try(:values).try(:first) || 0) * Xp.bonus(:order) +
          (progress['purifier parts discovered'] || 0) * Xp.bonus(:machine_part) +
          (progress['infernal parts discovered'] || 0) * Xp.bonus(:machine_part) +
          (progress['teleporters discovered'] || 0) * Xp.bonus(:teleporter_repair) +
          (progress['dungeons raided'] || 0) * Xp.bonus(:dungeon_raid) +
          (progress['undertakings'] || 0) * Xp.bonus(:undertaking) +
          (progress['deliverances'] || 0) * Xp.bonus(:deliverance) +
          (progress['maws plugged'] || 0) * Xp.bonus(:plug) +
          (progress['chunks explored'] || 0) * Xp.bonus(:explore) +
          (progress['chests looted'] || 0) * Xp.bonus(:loot) +
          (items_discovered_hash.try(:size) || 0) * Xp.bonus(:first_mine) +
          (items_crafted_hash.try(:size) || 0) * Xp.bonus(:first_craft) +
          (items_crafted || 0) * 0.1

        xp = [min_xp, calculated_xp].max.to_i
        level = Xp.level_for_xp(xp)
        pts = [level - achievements.size - 1, 0].max
        { achievements: achievements.size, min_xp: min_xp.to_i, calculated_xp: calculated_xp.to_i, xp: xp.to_i, level: level, points: pts }
      rescue
        p "[Xp] Legacy xp error: #{$!} #{$!.backtrace.first(3)}"
        return nil
      end
    end

  end
end
