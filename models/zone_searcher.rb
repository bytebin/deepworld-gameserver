class ZoneSearcher
  def initialize(for_player)
    @player = for_player
    @max    = 10
    @teasers = 3
    @fields = [:name, :players_count, :active_duration, :size, :chunk_size, :chunks_explored_count, :biome, :acidity, :premium, :protection_level, :scenario, :pvp, :market]
  end

  def search(type)
    @player.get_vitals(@player.followees, true) do |followees|
      followees ||= []

      if criteria = get_criteria(type, followees)
        if @player.zone.tutorial?
          send_results(type, [], followees)

        else
          if type == 'Random'
            if @player.free?
              criteria.where(ZoneSearcher.free).fields(@fields).random(@max - @teasers) do |zones|
                criteria.where(ZoneSearcher.premium).fields(@fields).random(@teasers) do |teaser_zones|
                  zones = ([zones] + [teaser_zones]).flatten
                  send_results(type, zones, followees)
                end
              end
            else
              criteria.fields(@fields).random(@max) do |zones|
                send_results(type, zones, followees)
              end
            end
          else
            # Send a few teasers for free players, and anything to premium players
            if @player.free?
              criteria.where(ZoneSearcher.free).fields(@fields).limit(50).randomlight(@max - @teasers) do |zones|
                criteria.where(ZoneSearcher.premium).fields(@fields).limit(50).randomlight(@teasers) do |teaser_zones|
                  zones = ([zones] + [teaser_zones]).flatten
                  send_results(type, zones, followees)
                end
              end
            else
              limit = %w{Private Owned Member}.include?(type) ? 200 : 50

              criteria.limit(limit).fields(@fields).randomlight(@max) do |zones|
                send_results(type, zones, followees)
              end
            end
          end
        end
      end
    end
  end

  #############
  # "Scopes"
  #############

  def self.free
    { premium: false }
  end

  def self.premium
    { premium: true }
  end

  def self.publik
    { active: true, private: false }
  end

  def self.publik_not_protected
    publik.merge(protection_level: nil)
  end

  def self.for_karma(karma)
    { '$or' => [{karma_required: nil}, {karma_required: {'$lte' => karma}}] }
  end

  def self.player_limit(limit)
    { players_count: {'$lte' => limit} }
  end

  private

  def private_zone_ids
    ((@player.owned_zones || []) + (@player.member_zones || [])).uniq
  end

  def get_criteria(type, online_followees)
    specific_biome = false

    case type
    when 'Recent'
      criteria = Zone.where(_id: { '$in' => @player.visited_zones.last(@max).reverse })
    when 'Private'
      criteria = Zone.where(_id: { '$in' => private_zone_ids })
    when 'Owned'
      criteria = Zone.where(_id: { '$in' => @player.owned_zones || [] })
    when 'Member'
      criteria = Zone.where(_id: { '$in' => @player.member_zones || [] })
    when 'Popular'
      criteria = Zone.where(ZoneSearcher.publik.merge('$and' => [{players_count: { '$gt' => 0 }}, {players_count: { '$lte' => Deepworld::Settings.search.max_players }}], market: { '$ne' => true })).sort(:players_count, -1)
    when 'Deadly'
      criteria = Zone.where(ZoneSearcher.publik).sort(:deaths, -1)
    when 'Friends'
      criteria = Zone.where(_id: { '$in' => online_followees.map{ |f| f.zone_id }.uniq },
        '$or' => [ { _id: { '$in' => private_zone_ids }}, self.class.publik ])
    when 'Bookmarked'
      criteria = Zone.where(_id: { '$in' => @player.bookmarked_zones || [] })
    when 'Random'
      criteria = Zone.where(ZoneSearcher.publik)
    when 'Market'
      criteria = Zone.where(ZoneSearcher.publik.merge(market: true))
    when 'Developed'
      criteria = Zone.where(ZoneSearcher.publik).sort(:items_placed, -1)
    when 'Unexplored'
      criteria = Zone.where(ZoneSearcher.publik_not_protected).sort(:chunks_explored_count)
    when 'Untouched'
      criteria = Zone.where(ZoneSearcher.publik_not_protected).sort(:items_mined)
    when 'Peaceful'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(difficulty: {'$lt' => 3}))
    when 'Challenging'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(difficulty: {'$gt' => 3}))
    when 'Hell'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'hell'))
      specific_biome = true
    when 'Arctic'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'arctic'))
      specific_biome = true
    when 'Desert'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'desert'))
      specific_biome = true
    when 'Deep'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'deep'))
      specific_biome = true
    when 'Brain'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'brain'))
      specific_biome = true
    when 'Space'
      criteria = Zone.where(ZoneSearcher.publik_not_protected.merge(biome: 'space'))
      specific_biome = true
    when 'PvP'
      criteria = Zone.where(ZoneSearcher.publik.merge(pvp: true))
    when 'Protected'
      criteria = Zone.where(ZoneSearcher.publik.merge(protection_level: 10))
    else
      # Cleanse non alpha numeric characters
      criteria = Zone.where(ZoneSearcher.publik.merge(name: /^#{Regexp.quote(type)}/i))
    end

    # Limit biome access for low survival skill
    #survival_skill = @player.adjusted_skill('survival')
    #criteria = criteria.where()  biome.survival_requirement

    # Exclude the players current zone, TODO: we'd have to recursively merge mongo keys
    # criteria = criteria.where({ id: { '$nin' => @player.zone_id }})

    # Do not show static zones
    criteria = criteria.where(static: { '$ne' => true })

    # Do not show beginner zones unless player has guide role
    unless @player.admin? || @player.role?('guide') || type == 'Recent'
      criteria = criteria.where(scenario: { '$ne' => 'Beginner' })
    end

    # Limit the returned data, and don't fire callbacks
    criteria = criteria.fields(@fields).callbacks(false)

    # Restrict alphas from PvP
    criteria = criteria.where(pvp: { '$ne' => true }) if @player.v3? && !@player.admin?

    criteria = criteria.where(biome: { "$ne" => "space" }) unless @player.client_version?("2.9.0") || specific_biome

    # Limit player count
    limit = @player.isolated ? 0 : Deepworld::Settings.search.max_players
    limit_exclusions = @player.isolated ? %w{Owned} : %w{Popular Owned}
    criteria = criteria.where(ZoneSearcher.player_limit(limit)) unless limit_exclusions.include?(type)
    criteria
  end

  def area_explored(zone)
    return 0 unless zone.size
    chunk_size = zone.chunk_size || [20, 20]
    chunk_count = (zone.size[0] / chunk_size[0]) * (zone.size[1] / chunk_size[1])
    area_explored = (((zone.chunks_explored_count || 0) / chunk_count.to_f) * 100).to_i
  end

  def send_results(type, zones, followees)
    results = zones.reject{ |z| z.id == @player.zone.try(:id) }.map do |zone|
      zone_followees = followees.select{ |f| f.zone_id == zone.id }
      accessibility = status = nil

      accessibility = zone.accessibility_for(@player)

      # Plain biome has toxic/purified status
      if zone.biome == 'plain'
        status = (zone.acidity || 0) < 0.1 ? 'purified' : 'toxic'
      end

      # Set the scenario
      scenario = nil
      if zone.market
        scenario = 'market'
      elsif zone.scenario.present?
        case zone.scenario
        when 'HomeWorld'
          scenario = 'Home'
        when 'TutorialGiftHomeWorld'
          scenario = nil
        else
          scenario = zone.scenario
        end
      elsif zone.pvp
        scenario = 'PvP'
      end

      [zone.id.to_s,
       zone.name,
       zone.players_count || 0,
       zone_followees.size,
       zone_followees ? zone_followees.map{ |f| f.name } : nil,
       zone.active_duration || 0,
       area_explored(zone),
       zone.biome || 'plain',
       status,
       accessibility,
       zone.protection_level || 0,
       scenario]
    end

    # Send after small delay to prevent throttling
    EventMachine::add_timer(Deepworld::Env.test? ? 0 : 0.1) do
      @player.queue_message ZoneSearchMessage.new(type, 0, 1, results, followees.size)
    end

  end
end
