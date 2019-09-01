module Entities
  module Effect
    class Base

      attr_reader :source, :target, :active_until

      def initialize(source, target, item, options)
        @source = source
        @target = target
        @item = item
        @options = Hashie::Mash.new(options)
      end

      def active?
        @active_until ? Ecosystem.time < @active_until : true
      end

      def process(delta_time)
        # Overridde
      end

      def range
        0 # Override
      end

      def source_distance
        @source.try(:position) && @target.try(:position) ? (@source.position - @target.position).magnitude.round(1) : nil
      end

      def within_range?
        source && range ? Math.within_range?(@source.position, @target.position, range) : true
      end

    end


    class Attack < Base

      attr_reader :method, :type, :amount, :slot

      def initialize(source, target, item, options)
        super

        @slot = @options[:slot]

        @type = options[:damage] ? options[:damage].first : @item.damage.first
        @amount = options[:damage] ? options[:damage].last : @item.damage.last
        @active_until = Ecosystem.time + duration
        @modifiers = options[:modifiers]
        @explosive = options[:explosive]

        check_critical_hit if can_critical_hit?
      end

      def duration
        @options[:duration] || @item.try(:damage_duration) || 0
      end

      def range
        if @item && source
          source.attack_range(@item)
        else
          @options[:range] || @item.try(:damage_range) || @item.try(:[], 'damage range') # TODO: Underscore only
        end
      end

      def process(delta_time)
        if within_range?
          @target.damage! damage(delta_time), @type, @source, true, @explosive
        end
      end

      def damage(delta_time)
        # Base damage
        amt = @amount * delta_time
        if @source.is_a?(Player) && @source.active_admin?
          amt *= 10
        else
          amt *= (1.0 - @target.defense(@type))
        end

        # Prep multiplier
        multiplier = 1.0

        if @modifiers
          @modifiers.each_pair do |type, mod|
            case type
            when :skill
              if @target.is_a?(Player)
                sk = @target.adjusted_skill_normalized(mod[0])
                multiplier += sk * mod[1]
              end
            end
          end
        end

        amt * multiplier.clamp(0, 2.0)
      end

      def can_critical_hit?
        !@target.try(:zone).beginner?
      end

      def check_critical_hit
        if chance = @item.try(:critical_hit)
          if Ecosystem.time > @source.last_critical_hit_at + 1.second
            if rand < chance * @source.critical_hit_rate
              position = (@target.position + Vector2[@target.size.x / 2, @target.size.y / -2]).fixed
              effect = { 'energy' => 'bomb-electric' }[@type] || 'bomb'
              @target.zone.explode position, 3, @source, false, damage(3.0), [@type, 'crushing'], effect, (1..999)
              @source.last_critical_hit_at = Ecosystem.time

              @source.notify 'Critical hit!', 4 if @source.is_a?(Player)
            end
          end
        end
      end

      def to_s
        "<Attack #{source.try(:entity_id)}->#{target.try(:entity_id)}=#{type} #{amount} range:#{range} #{'out of range: ' + source_distance.to_s unless within_range?} (#{duration >= 0 ? duration.to_s + 's' : 'instant'})>"
      end

    end

    class Defense < Base

      attr_reader :type, :amount

      def initialize(source, target, item, options)
        super

        @type = options[:type] || @item.type
        @amount = options[:amount] || @item.amount
        if d = duration
          @active_until = Ecosystem.time + d
        end
      end

      def duration
        @options[:duration] || @item.try(:duration)
      end

      def process(delta_time)

      end

    end

  end
end