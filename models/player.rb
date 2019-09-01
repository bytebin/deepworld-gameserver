class Player < MongoModel
  CURRENT_PLAYER_VERSION = 4
  DEFAULT_HEALTH = 5
  REFERRAL_BONUS = 50
  ADVERTISEMENT_PLAY_TIME_REQUIREMENT = 2.hours
  SOCIAL_PAGINATION = 100

  extend Forwardable
  include Entity
  include Entities::Effectable

  fields [:inv, :inventory, :inventory_locations, :version]
  fields [:name, :name_downcase, :email, :auth_tokens, :api_token, :client_configuration, :zone_id, :zone_name, :tutorial_zone_id, :platform, :admin, :premium, :upgrades, :invite_responses, :latency, :command_latency, :settings, :created_at, :last_active_at]
  fields [:current_client_version, :client_info, :time_zone]
  fields [:visited_zones, :owned_zones, :member_zones, :bookmarked_zones]
  fields [:play_time, :items_mined, :items_mined_hash, :items_placed, :items_placed_hash, :items_crafted, :items_crafted_hash, :items_workshopped, :items_workshopped_hash, :items_discovered, :items_discovered_hash, :items_looted, :items_looted_hash, :deaths, :crowns, :crowns_spent, :roles]
  fields [:keys, :hints, :casualties, :kills, :mobs_killed, :referrer, :loots, :directives, :ads, :waypoints, :block_overlaps]
  fields [:landmark_votes, :competition_votes, :landmark_last_vote_at, :last_post_viewed_at]
  fields [:tradees, :earthbombees]
  fields [:health, :next_regen_at, :emitter, :pvp_team, :last_changed_team_at, :sessions_count, :rewards, :activation_at]
  fields [:last_summoned_at]
  fields [:ref, :ref_sub, :signup_ip]
  fields :position, false
  fields :spawn_point, Vector2

  fields [:reportings, :reportings_count, :reportees, :reportees_count]

  include Players::Appearance
  fields [:wardrobe, :appearance]

  include Players::Chat
  fields [:mutings]
  attr_reader :recent_chats

  include Players::Obscenity
  fields [:obscenity, :obscenity_penalties, :muted, :muted_until]

  include Players::Karma
  fields [:karma, :karma_penalties, :suppressed, :suppressed_until]

  include Players::Jail
  fields [:jailed, :jailed_until]
  fields [:isolated, :isolated_until]

  include Players::Facebook
  fields [:facebook_id, :facebook_permissions]
  attr_reader :facebook_token

  include Players::Achievements
  fields [:achievements, :progress]
  attr_accessor :progress_notified

  include Players::FamilyName
  fields [:family_name]

  include Players::Orders
  fields [:orders, :primary_order]

  include Players::Xp
  fields [:xp, :level, :level_ups]

  include Players::Skills
  fields [:skills, :points, :skills_bumped, :skills_brained]

  include Players::Social
  fields [:followers, :followees]

  include Players::Segments
  fields [:segments]

  include Players::Cold
  fields :freeze

  include Players::Heat
  fields :thirst

  include Players::Breath
  fields :breath

  include Players::Password
  fields [:password_hash, :password_salt]

  include Players::Guild
  fields :guild_id
  attr_accessor :guild

  include Players::Quests
  fields [:quests, :active_quest]

  include Players::Sales
  fields [:last_sale_at, :sales_shown]

  include Players::DailyItem
  fields [:xp_daily, :last_daily_item_hint_at]

  include Players::Suppression
  attr_accessor :suppress_flight, :suppress_guns, :suppress_mining

  include Players::Happenings

  fields :daily_bonus

  include Players::Registration
  include Players::Notifications
  include Players::Visibility
  include Players::Reporting
  include Players::Admin
  include Players::Dialogs

  include Players::Support
  attr_accessor :small_screen, :is_initial_session

  def_delegators :@connection, :queue_message, :queue_peer_messages, :notify, :notify_peers, :kick, :peers, :disconnected

  attr_reader   :current_session, :last_saved_at, :trade, :used_notification_blocks, :teleport_position, :hints_in_session, :mobs_killed_streak
  attr_accessor :zone, :played, :ephemeral, :last_heartbeat_at, :last_attacks_at, :last_mining_natural, :last_mining_position, :last_used_inventory_at, :current_item, :placements, :stealth, :unread_missive_count, :missive_checks
  attr_accessor :current_session, :cheater, :mark_cheater_at
  attr_accessor :inv
  attr_accessor :connection, :socket, :admin_enabled
  attr_accessor :load_attempt
  attr_reader :servants, :directing_servant

  def_delegators :@inv, :gift_items!

  # Array of chunk indexes specifying which chunks the player currently has loaded
  attr_accessor :active_indexes
  attr_accessor :started_at, :ended_at, :area_explored

  def self.get_name(player_id)
    player_id = BSON::ObjectId(player_id) if player_id.is_a?(String)
    Player.where(_id: player_id).fields([:name]).callbacks(false).first do |player|
      yield player.try(:name)
    end
  end

  def after_initialize
    @segments ||= {}
    @last_step_at = Time.now
    @premium = true if @premium.nil? || @premium == '1'
    @premium = false if @premium == '0'

    if @upgrades.blank?
      #segment! 'biomes', Deepworld::Env.test? ? 'locked' : ['unlocked', 'locked']
      @upgrades = Players::Invite::UPGRADES.dup
    end

    @version            ||= 5

    @sessions_count     ||= 0
    @sessions_count     += 1

    get_current_session if connection

    prepare_wardrobe
    @inv                = PlayerInventory.new(self)
    @health             ||= DEFAULT_HEALTH
    @xp                 ||= 0
    @xp_daily           ||= {}
    @orders             ||= {}
    @level              ||= 1
    @level_ups          ||= {}
    @crowns             ||= 0
    @current_item       ||= 0
    randomize_appearance! unless (@appearance and @appearance.values.any?{ |a| a.is_a?(Fixnum) })
    fix_appearance

    @visited_zones      ||= []
    @owned_zones        ||= []
    @member_zones       ||= []
    @bookmarked_zones   ||= []
    @followers          ||= []
    @followees          ||= []

    @play_time          ||= 0
    @play_time_base     ||= @play_time
    @items_mined        ||= 0
    @items_mined_hash   ||= {}
    @items_discovered   ||= 0
    @items_discovered_hash ||= {}
    @items_looted       ||= 0
    @items_looted_hash  ||= {}
    @items_placed       ||= 0
    @items_placed_hash  ||= {}
    @items_crafted      ||= 0
    @items_crafted_hash ||= {}
    @items_workshopped      ||= 0
    @items_workshopped_hash ||= {}
    @deaths             ||= 0
    @landmark_votes     ||= 0
    @competition_votes  ||= {}
    @waypoints          ||= {}
    @rewards            ||= {}
    @facebook_permissions ||= {}
    @roles              ||= []

    @thirst             ||= 0
    @breath             ||= 1.0

    @obscenity          ||= 0
    @obscenity_penalties ||= 0

    @points             ||= 0
    @achievements       ||= {}
    @progress_notified  ||= {}
    clean_achievements
    @progress           ||= {}
    @keys               ||= []
    @hints              ||= {}
    @hints_in_session     = []
    @dialogs            ||= {}
    @karma              ||= 0
    @karma_penalties    ||= 0
    @loots              ||= []
    @directives         ||= []
    @pvp_team           ||= ['Red', 'Blue'].random
    @last_changed_team_at ||= Time.now - 1.day
    @quests             ||= {}

    @servants           ||= []

    migrate_reportings_to_mutings
    @mutings            ||= {}
    @recent_chats       ||= []

    @skills             ||= {}
    @skills_bumped      ||= []
    @skills_brained     ||= []
    set_default_skills!
    convert_for_xp! unless Deepworld::Env.test?

    @casualties         ||= []
    @kills              ||= []
    @mobs_killed        ||= {}
    @mobs_killed_streak ||= {}
    @tradees            ||= []
    @earthbombees       ||= []

    @active_indexes     = []
    @started_at         = Time.now
    @last_damaged_at    = Time.now - 1.minute
    @last_moved_at      = Time.now
    @last_heartbeat_at  = Time.now
    @last_saved_at      = Time.now
    @last_attacks_at    = {}
    @next_regen_at      ||= Time.now + regen_interval
    @last_sale_at       ||= @created_at
    @sales_shown        ||= {}
    @last_error_notification_at = Time.now
    @landmark_last_vote_at ||= Time.now - 1.day
    @last_used_inventory_at = Time.now
    @has_been_updated   = false
    @cache              = Cache.new
    @steps              = 0
    @load_attempt       ||= 0
    @used_notification_blocks = []
    @block_overlaps     ||= 0
    @missive_checks     = 0
    @unread_missive_count ||= 0
    @last_entity_tracking_at = Time.now

    # Timers
    @timer_queue  = []
    @timer_lock   = Mutex.new

    # Entity stuff
    @tracked_entity_ids = []

    @settings ||= { 'visibility' => 0 }

    # Ephemeral tracking
    @placements = Players::Placements.new(self)

    initialize_entity
  end

  def initialized?
    !@inv.nil?
  end

  def player?
    true
  end

  def npc?
    false
  end

  def current_client_version=(ver)
    @current_client_version = ver
    @is_v2 = @is_unity = nil
  end

  def role?(role)
    @roles.include?(role)
  end

  def play_time=(t)
    @play_time = t.to_i
  end

  def session_play_time
    @started_at ? Time.now - @started_at : 0
  end

  def after_add
    set_default_freeze
  end

  def ilk
    0
  end

  def category
    'avatar'
  end

  def digest
    @digest ||= id.digest
  end

  def follower_digest
    @cache.get(:follower_digest, 30) { followers.map(&:digest) }
  end

  def config
    cfg = {
      id: id.to_s,
      api_token: api_token,
      name: name,
      premium: premium,
      appearance: self.details,
      hints: hints,
      play_time: play_time,
      items_mined: items_mined,
      items_placed: items_placed,
      items_crafted: items_crafted,
      items_workshopped: items_workshopped,
      karma: karma_description,
      deaths: deaths,
      xp: xp,
      level: level,
      points: points,
      crowns: crowns,
      keys: keys,
      visited_zones: visited_zones.map{ |z| z.to_s },
      settings: settings,
      tutorial: Deepworld::Settings.player.tutorial,
      show_hints: @zone.show_hints?,
      facebook_id: facebook_id,
      breath: breath,
      mutings: mutings,
      family_name: family_name
    }
    cfg[:admin] = true if @admin == true
    cfg[:pvpg] = pvp_group if pvp_group
    cfg[:uni] = appearance_uniform if appearance_uniform
    cfg[:socket_sleep] = 0 if @admin == true || @zone.config['socket_sleep'] || Deepworld::Env.development?
    cfg[:test_movement] = true if (@admin == true || role?('beta') || role?('glitch') || @zone.config['test_movement']) || Deepworld::Env.development?

    # zone.update_attribute :config, { 'socket_sleep' => true, 'test_movement' => true, 'glitch_proof' => true }

    if show_ads?
      cfg[:show_ads] = true
      if @ads.is_a?(String)
        cfg[:ad_network] = @ads
      else
        cfg[:ad_network] = rand < 0.99 ? 'Tapjoy' : 'AdColony'
      end
    end

    cfg
  end

  def admin?
    @admin == true
  end

  def active_admin?
    @admin == true && @admin_enabled == true
  end

  def noob?
    play_time < 3600
  end

  def heartbeat_timeout
    if zone && (zone.tutorial? || zone.beginner?)
      return Deepworld::Settings.player.unregistered_timeout
    else
      return Deepworld::Settings.player.heartbeat_timeout
    end
  end

  def self.named(player_name, options = {})
    options[:callbacks] ||= false

    self.find_one({name_downcase: player_name.downcase}, options) do |player|
      yield player
    end
  end

  def details
    options = @settings['appearance'] || {}

    deets = appearance.merge({ 'l' => level, 'v' => visibility_setting, 'id' => self.id.to_s })

    # Additional appearance
    suit = self.inv.accessories.find{ |a| a.use['fly'] }
    deets['u'] = suit.code if suit
    deets['to*'] = 'ffff55'
    deets['fg*'] = 'ffff55'

    # Accessory appearance
    self.inv.accessories.each do |acc|
      if acc.appearance
        if options[acc.appearance] != false
          deets[acc.appearance] = acc.code
        else
          deets[acc.appearance] ||= 0
        end
      end
    end

    # Effects
    deets['em'] = emitter if emitter

    # Guilds & groups
    deets['gn'] = guild_short_name if guild_short_name
    deets['pvpg'] = pvp_group if pvp_group
    deets['uni'] = appearance_uniform if appearance_uniform

    # Order icon
    if icon = current_order_icon
      deets['ni'] = icon
    end

    deets
  end

  def send_peers_status_update
    unless zone.tutorial?
      queue_peer_messages EntityStatusMessage.new([self.status])
    end
  end

  def pvp?
    zone.pvp
  end

  def pvp_group
    case zone.scenario
      when 'Guild PvP' then guild_short_name
      when 'Team PvP' then pvp_team
      else nil
    end
  end

  def current_biome
    zone.biome
  end

  def current_biome?(biome)
    zone.biome == biome
  end

  def flag!(params)
    Flag.create({ 'player_id' => self.id, 'zone_id' => zone.id, 'position' => position.fixed.to_a, 'created_at' => Time.now }.merge(params))
  end

  def step
    step_time = Time.now - @last_step_at
    @play_time = @play_time_base + session_play_time

    if !@first_step && Time.now > @started_at + 4.seconds
      @first_step = true

      if zone.show_hints? && !@hints_in_session.include?(:login)
        if v3? && !client_version?('3.1.10')
          show_dialog [{ 'text' => "A new Windows beta is available that fixes many known issues. Please visit http://deepworldgame.com/download to install it." }]
          @hints_in_session << :login
        end

        if !registered? && play_time > (Deepworld::Env.production? ? 30.minutes : 5.minutes) && hint?('register1')
          request_registration
        elsif !registered? && play_time > (Deepworld::Env.production? ? 1.5.hours : 10.minutes) && hint?('register2')
          request_registration
        elsif !registered? && play_time > (Deepworld::Env.production? ? 2.5.hours : 15.minutes) && hint?('register3')
          request_registration
        elsif !registered? && play_time > (Deepworld::Env.production? ? 3.5.hours : 20.minutes) && hint?('register4')
          request_registration
        elsif !registered? && play_time > (Deepworld::Env.production? ? 4.5.hours : 25.minutes) && hint?('register5')
          request_registration
        else
          send_hint (touch? ? 'ios-swipe' : 'mac-hotkeys'), :login if play_time > 1.hour
          send_hint 'world-manage', :login if zone.private && zone.is_owner?(self.id) && !zone.locked
          send_hint 'report-players', :login if play_time > 4.hours
          send_hint 'protect-your-password', :login if play_time > 8.hours
          send_hint 'buy-premium-teleport', :login if !premium && play_time > 12.hours
          send_hint 'buy-private-zone', :login if play_time > 16.hours && owned_zones.blank?
          send_hint 'rate-in-app-store', :login if play_time > 24.hours && touch?
          send_hint zone.scenario.downcase.gsub(' ', '-') if zone.scenario.present?

          # Steam review request
          if client_version?('3.2.9') && play_time > 6.hours
            if hint?('rate-on-steam-1')
              show_dialog Game.config.dialogs.rate_on_steam, true do |vals|
                queue_message EventMessage.new('openUrl', 'http://store.steampowered.com/recommended/recommendgame/340810')
              end
              ignore_hint 'rate-on-steam-1'
            end
          end
        end
      end

      check_orders
      calculate_crowns_spent! unless crowns_spent
      begin_first_quest_if_necessary unless Deepworld::Env.test?
      zone.check_screenshot self if fast_device?
    end

    # Send all peer positions occasionally to avoid player getting "stuck" once untracked
    send_all_peer_positions if @steps % 20 == 4

    # Health
    regen!

    # Breath
    check_liquid if @steps % 4 == 0
    apply_breath Time.now - @last_step_at, @submerged_item.nil? unless Deepworld::Env.test?

    # Trading
    @trade.timeout_if_necessary if @trade && @trade.started_by?(self)

    # Stats
    step_obscenity step_time
    step_karma step_time

    # Happenings
    alert_happenings unless zone.tutorial? if @steps % 20 == 15

    # Marking session
    if !@session_marked && @zone && @current_session
      Analytics.track_event self, :design, @zone.tutorial? ? 'Tutorial:Enter' : 'Zone:Enter'
      @session_marked = true
    end

    # Journeyman achievement
    unless Deepworld::Env.test? || zone.tutorial? || zone.beginner? || has_achieved?("Journeyman")
      if @steps % 60 == 0
        if zone.meta_blocks_within_range(position, 20, 891, :zone_teleporter).blank?
          add_achievement "Journeyman"
        end
      end
    end

    @steps += 1
    @last_step_at = Time.now

    # Sales
    step_sales

    # Admin
    step_admin

    if mark_cheater_at && Time.now > mark_cheater_at && !role?("cheater")
      @roles << "cheater"
    end
  end

  def show_ads?
    !!@ads || (!premium && play_time > ADVERTISEMENT_PLAY_TIME_REQUIREMENT)
  end

  def command!(type, arguments)
    cmd = type.new(arguments, @connection)
    cmd.execute!
    cmd
  end

  def surrogate_mine!(arguments)
    cmd = BlockMineCommand.new(arguments, @connection)
    cmd.surrogate = true
    cmd.execute!
    cmd
  end

  def surrogate_place!(arguments)
    cmd = BlockPlaceCommand.new(arguments, @connection)
    cmd.surrogate = true
    cmd.execute!
    cmd
  end

  def notify_start_directing(servant = nil)
    @directing_servant = servant
    change 'dir' => true
  end

  def track_block_overlap(pos)
    @block_overlaps += 1
  end

  def away_from_spawn?(min_distance)
    zone.meta_blocks_within_range(position, min_distance, Game.item_code('mechanical/zone-teleporter'), :zone_teleporter).blank?
  end

  def can_place_bomb?(position)
    suppressor = Game.item('mechanical/bomb-suppressor')
    zone.meta_blocks_within_range(position, suppressor.power, suppressor.code, :steam).none?{ |mb| mb[1].peek(FRONT)[1] == 1 }
  end

  def owns_current_zone?
    zone.owners.include?(self.id)
  end

  def belongs_to_current_zone?
    zone.members.include?(self.id)
  end

  def tutorial?
    zone.tutorial?
  end




  # ===== Posts ===== #

  def send_posts(posts, force = false)
    if v2? && zone.show_hints? && !@hints_in_session.include?(:login)
      if force || last_post_viewed_at.nil? || posts.first.published_at > last_post_viewed_at
        post = posts.first
        show_dialog [{ 'title' => post.title, 'text' => post.content }], false
        @last_post_viewed_at = post.published_at
      end
    end
  end

  # ===== Chunks / indexes ===== #

  # Index of the players current chunk
  def current_chunk_index
    @zone.chunk_index(@position.x, @position.y)
  end

  def add_active_indexes(indexes)
    raise "One or more indexes out of bounds: #{indexes}" unless indexes.all?{ |i| (0..zone.chunk_count).include?(i) }

    @active_indexes += indexes
    @active_indexes.uniq!
  end

  def remove_active_indexes(indexes)
    @active_indexes -= indexes
  end

  def chunk_light_message
    LightMessage.message_for_indexes(zone, @active_indexes)
  end

  def active_in_chunk?(chunk_index)
    @active_indexes.include?(chunk_index)
  end


  # ===== Stats ===== #

  def current_item_group
    Game.item(@current_item).try(:group)
  end

  def current_item_group?(group)
    current_item_group == group
  end

  def item_types_mined
    @items_mined_hash.keys.size
  end

  def mined_item(item, position, meta_block, owner_digest)
    @items_mined += 1
    @items_mined_hash[item.code.to_s] ||= 0
    @items_mined_hash[item.code.to_s] += 1

    if owner_digest == 0
      add_xp :first_mine, 'New item mined!' if @items_discovered_hash[item.code.to_s].blank?
      add_xp item.xp

      @items_discovered += 1
      @items_discovered_hash[item.code.to_s] ||= 0
      @items_discovered_hash[item.code.to_s] += 1
    end

    # Track change
    track_inventory_change :mine, item, 1, position
    @last_mining_position = position
    @last_mining_natural = owner_digest == 0
    event! :mine, item

    notify_stat_if_milestone 'mined', 'block', @items_mined
  end

  def mining_bonus(item)
    mining_tool = Game.item(@current_item)
    tool_multiplier = mining_tool && item.mining_bonus.tool == mining_tool.group ? mining_tool.bonus || 1.0 : 0
    accessory_multiplier = item.mining_bonus.accessory && inv.accessory_with_use(item.mining_bonus.accessory) ? 2.0 : 1.0
    item.mining_bonus.chance * adjusted_skill_normalized(item.mining_bonus.skill) * tool_multiplier * accessory_multiplier
  end

  def place_item(item, position)
    @items_placed += 1
    @items_placed_hash[item.code.to_s] ||= 0
    @items_placed_hash[item.code.to_s] += 1

    placements.place(position, item)

    # Track change
    track_inventory_change :place, item, -1, position unless item.place_entity
    event! :place, item
  end

  def crafted_item(item, quantity = 1)
    if @items_crafted_hash[item.code.to_s].blank?
      add_xp :first_craft, 'New item crafted!'
    else
      add_xp item.craft_xp if item.craft_xp
    end

    @items_crafted += quantity
    @items_crafted_hash[item.code.to_s] ||= 0
    @items_crafted_hash[item.code.to_s] += quantity

    if item.crafting_helpers
      @items_workshopped += quantity
      @items_workshopped_hash[item.code.to_s] ||= 0
      @items_workshopped_hash[item.code.to_s] += quantity
    end

    # Track change
    track_inventory_change :craft, item, quantity
    event! :craft, item
  end

  def crafting_bonus_for_item?(item)
    # TODO: Configurable via YAML
    enhancers = { 'metallurgy' => { 'code' => 852, 'mod' => 1, 'distance' => 3, 'index' => 'steam' }}

    enhancers.each_pair do |crafting_group, details|
      if item.inventory_category == crafting_group
        blocks = zone.meta_blocks_within_range(position + Vector2[-1, 0], details['distance'], details['code'], details['index'].to_sym)
        if !details['mod'] || blocks.values.any?{ |mb| zone.peek(mb.x, mb.y, FRONT)[1] == details['mod'] }
          return Game.item(details['code'])
        end
      end
    end
    false
  end

  def item_types_crafted
    @items_crafted_hash.keys.size
  end

  def item_types_workshopped
    @items_workshopped_hash.keys.size
  end

  def track_inventory_change(action, item, quantity, position = nil, other_player = nil, other_item = nil, other_quantity = nil)
    Game.track_inventory_change self, action, item, quantity, position, other_player, other_item, other_quantity

    case action
    when :loot
      code = (item.is_a?(Fixnum) ? item : item.try(:code)).to_s
      @items_looted += quantity
      @items_looted_hash[code] ||= 0
      @items_looted_hash[code] += quantity
    end
  end

  def loot?(loot_code)
    @loots.include?(loot_code)
  end


  # ===== Notifications ===== #

  def notify_self_and_peers(self_msg, peer_msg)
    notify "You #{self_msg}", 10
    notify_peers "#{name} #{peer_msg}", 11
  end

  def notify_stat_if_milestone(verb, noun, count)
    if desc = Game.config.milestones[count]
      notify_self_and_peers "#{verb} your #{desc} #{noun}!", "#{verb} their #{desc} #{noun}!"
    end
  end



  def update_setting(key, value, update_database = false)
    @settings[key] = value
    update(settings: @settings)
  end


  # ===== Landmarks ===== #

  def landmark_vote_interval
    if landmark_votes > 1000
      3.hours
    elsif landmark_votes > 500
      6.hours
    else
      12.hours
    end
  end



  # ===== Trading ===== #

  def accepts_trade?(other_player = nil)
    @settings['trading'] != false && !has_muted?(other_player)
  end

  def trade_item(other_player, item_code)
    item = Game.item(item_code)
    return false unless item

    if suppressed?
      alert "Cannot trade while karma is bottomed out." and return false
    end

    if item.tradeable == false
      alert "Cannot trade #{item.title.downcase}." and return false
    end

    # Check for tradeable zone
    unless zone.can_trade?
      # Get a random semi-popular market zone
      Zone.where(ZoneSearcher.publik.merge({
        market: true,
        players_count: { '$lt' => Deepworld::Settings.search.max_players - 2}
        })).sort(:players_count, -1).limit(10).random do |z|

        text = "Trading is only allowed in Market worlds and private worlds. Ask the player to join you in a Market world."
        text << " '#{z.first.name}' is a good choice." unless z.empty?

        self.show_dialog([{'title' => 'Trade at the Market!', 'text' => text}], false)
      end

      return false
    end

    # Don't allow free players to give or receive valuable items
    if item.tradeable == 'premium'
      alert "You must have a premium account to trade that item." and return false if free?
      alert "#{other_player.name} must have a premium account to trade that item." and return false if other_player.free?
    end

    if item.tradeable == 'leveled'
      lv = 20
      alert "You must be premium or level #{lv}+ to trade that item." and return false if (free? && level < lv)
      alert "#{other_player.name} must be premium or level #{lv}+ to trade that item." and return false if (other_player.free? && other_player.level < lv)
    end

    if item.place_entity && !can_place_entity?(item)
      alert "Cannot trade servant while active."
      return false
    end

    if @trade.present?
      if @trade.between?(other_player, self)
        @trade.continue self, [item_code]
        return
      else
        @trade.abort! "Trade has been cancelled by #{name}."
      end
    end

    @trade = Trade.new(self, other_player, item_code)
  end

  def join_trade(trade)
    if @trade.blank?
      @trade = trade
    else
      trade.abort!
    end
  end

  def end_trade(trade)
    @trade = nil if trade == @trade
  end



  # ===== Servants ===== #

  def can_place_entity?(item)
    entity_config = Game.entity(item.place_entity)

    inv.contains?(item.code, @servants.count{ |s| s.ilk == entity_config.code } + 1)
  end

  def own_entity!(entity)
    entity.owner_id = @id
    @servants << entity if entity.servant?
  end

  def servant_died!(entity)
    @servants.delete entity
  end




  # ===== Hints ===== #

  def send_hint(hint, session_key = nil)
    return false if session_key && @hints_in_session.include?(session_key)

    if !@hints[hint]
      if cfg = Game.config.hints[hint]
        if cfg.dialog
          notify_list cfg.pages
          ignore_hint hint
        else
          queue_message HintMessage.new(hint, position.x, position.y - 2)
        end

        @hints_in_session << session_key if session_key

        return true
      end
    end
    false
  end

  def ignore_hint(hint)
    @hints[hint] = self.play_time
  end

  def hint?(hint)
    if @hints[hint]
      false
    else
      @hints[hint] = Time.now
      true
    end
  end



  # ===== Minigames ===== #

  def in_minigame?
    @active_minigame.present?
  end

  def join_minigame(minigame)
    @active_minigame = minigame
  end

  def end_minigame
    @active_minigame = nil
  end




  # ===== Persistence ===== #

  def save_initial!
    if visited_zones.blank? && self.zone_id != self.tutorial_zone_id
      queue_message EventMessage.new('adjust', 'c23lr9') unless Deepworld::Env.test?
    end

    visited_zones.delete self.zone_id
    visited_zones << self.zone_id unless zone.try('static?') || !zone.show_in_recent?

    updates = {
      zone_name: self.zone.name,
      visited_zones: visited_zones.last(20),
      current_ip: @connection.ip_address,
      last_active_at: Time.now,
      current_client_version: current_client_version
    }
    unless @api_token
      updates[:api_token] = Deepworld::Token.generate(16)
    end

    update(updates)
  end

  # Saves the player
  def save!(options = {}, &block)
    return true if ephemeral

    updates = {
      wardrobe: wardrobe,
      health: health,
      next_regen_at: next_regen_at,
      position: position.try(:to_ary),
      appearance: appearance,
      last_active_at: Time.now,
      latency: latency,
      command_latency: command_latency,
      play_time: play_time,
      settings: settings,
      items_mined: items_mined,
      items_mined_hash: items_mined_hash,
      items_discovered: items_discovered,
      items_discovered_hash: items_discovered_hash,
      items_placed: items_placed,
      items_placed_hash: items_placed_hash,
      items_crafted: items_crafted,
      items_crafted_hash: items_crafted_hash,
      items_workshopped: items_workshopped,
      items_workshopped_hash: items_workshopped_hash,
      items_looted: items_looted,
      items_looted_hash: items_looted_hash,
      deaths: deaths,
      points: points,
      crowns: crowns,
      xp: xp,
      xp_daily: xp_daily,
      progress: progress,
      skills: skills,
      kills: kills,
      mobs_killed: mobs_killed,
      casualties: casualties,
      tradees: tradees,
      keys: keys,
      hints: hints,
      karma: karma,
      loots: loots,
      directives: directives.uniq,
      freeze: freeze ? freeze.to_f : nil,
      thirst: thirst.to_f,
      breath: breath.to_f,
      emitter: emitter,
      version: version,
      landmark_last_vote_at: landmark_last_vote_at,
      last_post_viewed_at: last_post_viewed_at,
      pvp_team: pvp_team,
      last_changed_team_at: last_changed_team_at,
      sessions_count: sessions_count,
      waypoints: waypoints,
      block_overlaps: block_overlaps,
      client_info: client_info,
      obscenity: obscenity,
      active_quest: active_quest,
      updated_at: Time.now
    }.merge(options)

    update(updates) do
      @last_saved_at = Time.now
      yield if block_given?
    end
  end

  def save_incremental!(options = {}, &block)
    return true if ephemeral

    updates = {
      last_active_at: Time.now
    }

    update(updates) do
      yield if block_given?
    end
  end

  def max_health
    skill = adjusted_skill('stamina').clamp(1, 10)
    DEFAULT_HEALTH + ((skill - (skill == 10 ? 0 : 1)) * 0.5)
  end

  def max_speed
    Vector2[12, 25]
  end

  def max_mining_distance
    5 + (adjusted_skill('mining') || 1) / 3
  end

  def max_placing_distance
    mult = inv.accessory_with_use('building extension') ? 2 : 1
    5.lerp(13, adjusted_skill('building') / 15.0).ceil * mult
  end

  def can_mine_through_walls?(item)
    false
  end

  def move!(new_position = nil, send_message = true)
    @pos_fixed = nil
    self.position = new_position if new_position
    queue_message PlayerPositionMessage.new(@position.x, @position.y, @velocity.x, @velocity.y)
  end

  def teleport!(new_position, validate = true, effect = nil, protection_player = nil)
    pos = Vector2[new_position[0], new_position[1]]

    if validate && !active_admin?
      destination_item = Game.item(@zone.peek(pos.x, pos.y, FRONT)[0])
      unless destination_item.use['zone teleport']
        if !@zone.area_explored?(pos)
          alert "That area hasn't been explored yet." and return false
        end

        unless destination_item.use['teleport'] || @zone.competition? || @zone.machine_allows?(self, 'teleport', 'tp_protected')
          if @zone.block_protected?(pos, self, false, nil, true)
            alert "That area is protected." and return false
          end
        end
      end
    end

    @teleport_position = pos
    queue_message TeleportMessage.new(pos.x, pos.y)
    move! pos, !v3?
    zone.queue_message EffectMessage.new((pos.x + 0.5) * Entity::POS_MULTIPLIER, (pos.y - 0.75) * Entity::POS_MULTIPLIER, effect, 20) if effect
    true
  end

  def event!(name, data = nil)
    @zone.player_event self, name, data
  end

  def event_message!(name, data)
    if name == 'hintOverlay' && v2? && !client_version?('2.5.0')
      if data['title'] == 'Quest Tip'
        alert_profile 'Quest Tip', data['text']
      end
    else
      queue_message EventMessage.new(name, data)
    end
  end

  def can_be_targeted?(entity = nil)
    alive? && !stealthy?
  end

  def stealthy?
    @stealth == true
  end



  # ===== Effects ===== #

  def consume(item, details = nil)
    Items::Consumable.new(self, item: item).use!(details)
  end

  def add_timer(delay, timer)
    @timer_lock.synchronize do
      @timer_queue << [Time.now + delay, timer]
    end
  end

  def remove_timers(timer)
    @timer_lock.synchronize do
      @timer_queue.reject!{ |t| t[1] == timer }
    end
  end

  def process_timers
    time = Time.now

    ready_timers = []

    @timer_lock.synchronize do
      # Get timers that are ready
      ready_timers = @timer_queue.select{ |timer| time > timer[0] }
      @timer_queue.reject!{ |timer| ready_timers.include?(timer) }
    end

    ready_timers.each do |timer|
      process_timer timer[1]
    end
  end

  def process_timer(timer)
    case timer
    when 'end stealth'
      @stealth = nil
      change 'xs' => 0
    end
  end




  # ===== Health and death ===== #

  def regen_interval
    regen_base_interval * (self.inv.regeneration || 1.0)
  end

  def regen_base_interval
    30.seconds
  end

  def regen_amount
    0.333
  end

  def can_regen?
    Time.now > next_regen_at && Time.now > last_damaged_at + (regen_interval * 2)
  end

  def regen!(force = false)
    if force || can_regen?
      heal! regen_amount
      @next_regen_at = Time.now + regen_interval
    end
  end

  def heal!(amount, send_message = true)
    unless health <= 0 or health >= max_health
      self.health = [health + amount, max_health].min
      queue_message HealthMessage.new(self.health) if send_message
    end
  end

  def damageable?
    !active_admin?
  end

  def after_damage(send_message = true)
    # Not quite dead, so just send a health message
    queue_message HealthMessage.new(self.health) if send_message
  end

  # Kill the player
  def die!(attacker = nil, explosive = false)
    zone.deaths += 1
    @deaths += 1
    @health = 0
    warm false
    apply_breath 1.0, true

    # Track attacker
    if attacker.is_a?(Player)
      track_casualty attacker
      attacker.track_kill self
    end

    death_status = status(STATUS_DEAD, attacker ? { '<' => attacker.entity_id } : {})
    queue_peer_messages EntityStatusMessage.new([death_status])
    event! :death, attacker

    @mobs_killed_streak.clear
  end

  def respawn!(send_messages = true)
    send_spawn_effect if send_messages && !active_minigame

    self.position = active_minigame.try(:spawn_point, self) || self.spawn_point
    self.health = max_health if health == 0

    if send_messages
      queue_message PlayerPositionMessage.new(self.position.x, self.position.y, 0, 0)
      queue_message HealthMessage.new(self.health)
      queue_peer_messages EntityStatusMessage.new([status(STATUS_REVIVED)])
      send_spawn_effect unless active_minigame
    end
  end

  def send_spawn_effect(pos = nil)
    pos ||= self.position
    msg = EffectMessage.new((pos.x + 0.5) * Entity::POS_MULTIPLIER, (pos.y - 0.75) * Entity::POS_MULTIPLIER, 'spawn', 20)

    zone.tutorial? ? self.queue_message(msg) : zone.queue_message(msg)
  end



  # ===== Combat ===== #

  def attack(entity, item, slot)
    if can_attack?(entity, item)
      entity.add_attack self, item, slot: slot
      @last_attacks_at[item.code] = Time.now
    end
  end

  def can_attack?(entity, item)
    if item.attack_interval
      return false if @last_attacks_at[item.code] && Time.now < @last_attacks_at[item.code] + item.attack_interval
    end

    true
  end

  def track_casualty(attacker)
    if attacker.is_a?(Player)
      @casualties.increment_subarray attacker.epoch_id
      Achievements::KillerAchievement.new.check(self)
    end
  end

  def track_kill(victim, explosive = false)
    is_active_deathmatch = active_minigame && active_minigame.respond_to?(:pvp?) && active_minigame.pvp?
    is_pvp = is_active_deathmatch || zone.pvp

    if victim.is_a?(Player)
      if is_pvp
        @kills.increment_subarray victim.epoch_id
        Achievements::KillerAchievement.new.check(self)
        steal_from_player victim

      # Non-PvP/minigame - ding karma
      elsif victim != self && victim.active_minigame.blank?
        penalty = @last_kill_karma && Time.now - @last_kill_karma < 1.second ? 3 : 10
        penalize_karma penalty
        @last_kill_karma = Time.now
      end
    else
      # Give the killing player the achievement
      Achievements::HuntingAchievement.new.check(self, victim)

      increment_mob_kills victim
    end

    event! :kill, victim
    event! :explode, victim if explosive
  end

  def increment_mob_kills(entity)
    return unless entity.code

    code = entity.code.to_s
    add_xp :first_kill, 'New creature killed!' if mobs_killed[code].blank?

    mobs_killed[code] ||= 0
    mobs_killed[code] += 1
    mobs_killed_streak[code] ||= 0
    mobs_killed_streak[code] += 1
  end

  def players_killed
    @kills.size
  end

  def player_kills
    @kills.sum{ |k| k[1] }
  end

  def players_killed_by
    @casualties.size
  end

  def mob_kills(code)
    @mobs_killed[code.to_s]
  end

  def steal_from_player(other_player)
    # Nuthin yet
  end

  def send_peers_pvp_team_message
    queue_peer_messages NotificationMessage.new("#{name} joined the #{pvp_team.downcase} team.", 11) if zone.scenario == 'Team PvP'
  end


  # ===== Trading ===== #

  def track_trade(other)
    @tradees.increment_subarray other.epoch_id
    Achievements::TradingAchievement.new.check(self)
  end

  def earthbomb(other)
    @earthbombees.increment_subarray other.epoch_id

    # TODO: Cool effect...
    # spawn = Npcs::Npc.new(Game.entity('bullets/earth'), zone, other.position)
    # spawn.set_details({ '<' => entity_id, '>' => other.entity_id, '*' => true, 's' => 2})
    # spawn.set_details('#' => (9..14).random.to_i)
    # zone.add_client_entity spawn

    update earthbombees: @earthbombees do
      Achievements::TradingAchievement.new.check(self)
    end
  end

  def players_traded
    @tradees.size
  end

  def players_earthbombed
    @earthbombees.size
  end

  def get_current_session
    Session.get_current(self.id) do |session|
      if session
        mark_current_session session
      else
        Session.record self do |session|
          mark_current_session session, true
        end
      end

      mark_activation unless @activation_at
    end
  end

  def mark_current_session(session, is_new = false)
    @current_session = session
    @current_session.is_new = is_new
    update last_session_id: session.id
  end

  def mark_activation
    unless @sessions_count == 1 || (@current_session && @current_session.first)
      # Record if player has just activated (secondary session)
      self.update(activation_at: Time.now)
    end
  end

  # Records stats for this play session
  def record_session
    begin
      @ended_at = Time.now
      Session.record(self)
    rescue
      p "Critical error: #{$!}"
    end
  end

  # Check that the players position is valid, or buried
  def position_check!
    position.x = position.x.clamp(0, zone.size.x - 1)
    position.y = position.y.clamp(1, zone.size.y - 1)

    # Check if buried
    if items_beneath.detect {|i| i.whole}  && !Deepworld::Env.development?
      self.position = self.spawn_point
    end
  end

  def items_beneath
    pos = position.fixed

    items = []
    items << Game.item(zone.peek(pos.x, pos.y - 1, FRONT)[0]) if zone.in_bounds?(pos.x, pos.y - 1)
    items << Game.item(zone.peek(pos.x, pos.y, FRONT)[0]) if zone.in_bounds?(pos.x, pos.y)

    items
  end

  def prepare_wardrobe
    @wardrobe ||= []

    # Add all wardrobe for admins
    if self.admin
      @wardrobe = Game.config.wardrobe_items.map(&:code)
    end

    # Remove any wardrobe objects which are base
    @wardrobe.reject!{ |i| Game.item(i).try(:base) == true }
  end

  def send_to(zone_id, force = false, send_to_position = nil)
    if jailed? && !force
      send_to_jail
      return
    end

    if zone && zone.id == zone_id && !force
      alert "You are already in #{zone.name}."
      return
    end

    # Nil the zone, and let gateway set it
    if zone_id == nil
      self.save!({ zone_id: nil, spawn_point: nil, position: nil}) do
        zone.remove_player(self) if zone
        kick("Teleporting...", true)
      end

    # Specific zone has been requested
    else
      Zone.where(_id: zone_id).callbacks(false).first do |new_zone|
        error = nil

        unless admin || force || self.owned_zones.include?(zone_id)
          if new_zone.karma_required && karma < new_zone.karma_required
            error = "Your karma is not high enough for that world."
          elsif (new_zone.players_count || 0) >= (new_zone.capacity || new_zone.default_capacity)
            error = "That world is at capacity! Try back in a little bit."
          elsif new_zone.premium && !self.premium
            error = "You need to upgrade to a premium account to visit that world."
          elsif !new_zone.can_play?(self.id)
            error = "You do not belong to that world."
          end
        end

        if error
          alert error
        else
          self.save!({ zone_id: new_zone.id, spawn_point: nil, position: send_to_position}) do
            zone.remove_player(self)
            queue_message EventMessage.new('playerWillChangeZone', nil);
            kick "Teleporting...", true
          end
        end
      end
    end
  end

  def send_to_spawn_zone!
    Teleportation.spawn! self
  end

  def send_to_spawn_zone_after_delay!
    EM.add_timer(2.0) do
      Teleportation.spawn! self
    end
  end

  def default_graphics_quality
    case platform
      when 'iPad 2G', 'iPhone 4S' then 1
      when 'iPad 1G', 'iPhone 4', 'iPhone 3GS', 'iPod touch 4G', 'iPod touch 3G' then 2
      else 0
    end

    #self.settings = { 'visibility' => 0, 'graphicsQuality' => graphics_quality }
  end

  def platform_group
    case @platform
    when /^iPh/
      'iPhone'
    when /^iPo/
      'iPod'
    when /^iPa/
      'iPad'
    when /^Mac/
      'Mac'
    when nil
      'Unknown'
    else
      @platform
    end
  end



  # ===== Entity & peer tracking ===== #

  # Find all entities in visible range + peers and update if player is tracking them or not
  def update_tracked_entities
    b = Benchmark.measure do
      # Determine which NPCs and peers are visible
      visible = self.visible_entities.map(&:entity_id)
      visible += self.locateable_peers.map(&:entity_id) unless @zone.tutorial? && !admin

      # Send status for added/removed NPCs
      departed = @tracked_entity_ids - visible
      entered = visible - @tracked_entity_ids
      npcs_statuses = []
      npcs_statuses += extract_npcs(entered).map{|e| @zone.entities[e].try(&:status)}.compact unless entered.empty?
      npcs_statuses += extract_npcs(departed).map{|e| Entity.exit_status(e) if e }.compact unless departed.empty?
      queue_message EntityStatusMessage.new(npcs_statuses) unless npcs_statuses.empty?

      # Send inventory use commands for newly visible players
      send_peers_inventory_use extract_players(entered)

      # Update tracked entities
      @tracked_entity_ids = visible
    end

    @zone.increment_benchmark :updated_tracked_entities, b.real
  end

  def visible_entities
    return unless @zone

    radius = Deepworld::Settings.player.entity_radius
    radius = (radius * 0.5).to_i if small_screen?
    radius = (radius * 1.3).to_i if skill('perception') >= 8

    questers = []
    if !@zone.tutorial? && self.position
      questers = @quests.size < 2 ?
        @zone.questers :
        @zone.questers.select{ |q| q.position && (q.position - self.position).magnitude <= 100 }
    end

    (@zone.npcs_in_range(self.position, radius) + questers).uniq
  end

  def locateable_peers
    self.peers.select{ |pl| pl.locateable_to_player?(self) }
  end

  def extract_players(entity_ids)
    entity_ids.select{ |e| @zone.entities[e].try(:player?) }
  end

  def extract_npcs(entity_ids)
    entity_ids.select{ |e| @zone.entities[e].try(:npc?) }
  end

  def extract_alive(entity_ids)
    entity_ids.select{ |e| @zone.entities[e].try(:alive?) }
  end

  def tracking_entity?(entity_id)
    @tracked_entity_ids.include?(entity_id)
  end

  def send_peers_inventory_use(peers_or_ids = nil)
    peers_or_ids ||= self.peers
    selected_peers = peers_or_ids.map{ |peer| peer.is_a?(Fixnum) ? @zone.entities[peer] : peer }
    item_use_statuses = selected_peers.select{| p| p.current_item > 0 }.map{ |p| p.current_inventory_use_data(0) }
    queue_message EntityItemUseMessage.new(item_use_statuses) if item_use_statuses.count > 0
  end

  def send_all_peer_positions
    return if (@zone.tutorial? && !admin)

    alive_peers = peers.select{ |peer| peer.alive? }
    queue_message EntityPositionMessage.new(alive_peers.map{ |peer| peer.position_array }) unless alive_peers.blank?
  end

  def send_entity_positions(only_moving = true, only_npc = false)
    return unless @ready_for_entities && Time.now > @last_entity_tracking_at + 0.5

    update_tracked_entities
    ent_ids = extract_alive(only_npc ? extract_npcs(@tracked_entity_ids) : @tracked_entity_ids)
    positions = only_moving ? zone.moved_entity_positions(ent_ids) : zone.all_entity_positions(ent_ids)

    queue_message EntityPositionMessage.new(positions) unless positions.blank?

    @last_entity_tracking_at = Time.now
  end

  def peers
    @zone.players - [self]
  end

  def before_quit
    @trade.abort! "#{self.name} abandoned the trade" if @trade

    servants_ = @servants.dup
    @servants.clear
    servants_.each { |servant| servant.die! }

    Analytics.track_event self, :design, zone.tutorial? ? 'Tutorial:Exit' : 'Zone:Exit'
  end

  # Misc

  def current_inventory_use_data(status)
    [@entity_id, 0, @current_item, status]
  end

  def inspect
    "<Player #{@name} #{@id}>"
  end

  # Set necessary player values and send initialization messages to client
  def zone_changed!
    spawned_at_entry = @position.nil?

    # Set the players spawn point and positions if necessary
    @spawn_point        ||= zone.next_spawn_point(self)
    self.position       ||= @spawn_point
    @area_explored      = Rect.new(@position.x, @position.y, 1, 1)

    # Respawn player if health is 0
    respawn!(false) if @health <= 0

    position_check!

    # Save the player
    save_initial!

    # Client setup messages
    Game.config.data_async(self) do |config_data|
      queue_message ClientConfigurationMessage.new(entity_id, config, config_data, zone.client_config(self))
      queue_message ZoneStatusMessage.new(zone.status_info(self))
      queue_message zone.machines_status_message(self)
      queue_message PlayerPositionMessage.new(position.x, position.y, 0, 0)
      send_skills_message
      queue_message HealthMessage.new(health)
      send_freeze_message
      queue_message InventoryMessage.new(@inv.to_h)
      queue_message WardrobeMessage.new(wardrobe)
      if meta = zone.all_meta_blocks_message(self)
        queue_message meta
      end

      # Peer status
      unless @zone.tutorial? && !admin
        # All peers
        queue_message EntityStatusMessage.new(peers.map{ |peer| peer.status }) unless peers.blank?
        send_all_peer_positions

        # Send death status for dead peers so they don't appear alive
        dead_peers = peers.select{ |p| p.dead? }
        queue_message EntityStatusMessage.new(dead_peers.map{ |p| p.status(STATUS_DEAD) }) unless dead_peers.blank?
      end

      # Entity status and positions
      @ready_for_entities = true
      @tracked_entity_ids = [] # Refresh tracking
      send_entity_positions(false, true) # Send only NPC positions, since peer positions were already sent

      # Existing player item use
      send_peers_inventory_use

      # Existing player achievements / progress
      ach = completed_achievements
      queue_message AchievementMessage.new(ach.keys.map{ |ach| [ach, 0] }) unless ach.blank?
      if achievement_progress_msg = Achievements.progress_summary_message(self)
        queue_message achievement_progress_msg
      end

      # Welcome player to zone (also triggers scene start on client, so should be last)
      if v3?
        notify zone.welcome_message, 6
        queue_message EventMessage.new('zoneEntered', nil)
      else
        notify zone.welcome_message, 333
      end

      # Startup achievements
      check_startup_achievements

      # Apply any pending transactions
      Transaction.apply_pending(self)

      # Give welcome gift
      Campaign.give_items(self) unless @zone.tutorial?

      # Any current maintenance message
      notify Game.maintenance, 503 if Game.maintenance.present?

      unless Deepworld::Env.test?
        send_initial_social_messages
        send_freeze_message
        send_thirst_message

        send_spawn_effect if spawned_at_entry
        update_order_icon

        notify "All chats are muted.", 9 if has_muted_all?

        check_registration!

        # Quests
        send_initial_quest_messages

        # Minigames
        zone.rejoin_minigame self
      end

      self.facebook_connect(ENV['FB_TOKEN'], false) if ENV['FB_TOKEN']

      event! :entered, self
    end
  end

  def convert_premium!(with_dialog = true)
    update(premium: true) do
      if with_dialog
        self.show_dialog [{ title: 'You are now a premium player!',
          list: [{ image: "shop/premium", text: "The entire Deepworld universe is yours\nto explore. Enjoy!" }]}]
      end

      self.queue_message StatMessage.new('premium', true)

      return unless self.referrer

      # Get the player name and add the referred bonus
      Player.find_by_id(self.referrer, callbacks: false) do |p|
        Transaction.create(player_id: self.id, amount: REFERRAL_BONUS, source: 'referred', source_identifier: p.name, pending: true, created_at: Time.now)
      end

      Transaction.create(player_id: self.referrer, amount: REFERRAL_BONUS, source: 'referral', source_identifier: self.name, pending: true, created_at: Time.now)
    end
  end

  def self.get(ids, fields = [:_id, :name, :zone_id], &block)
    yield nil unless ids.present?

    Player.where(_id: { '$in' => ids }).fields(fields).callbacks(false).all do |players|
      yield players
    end
  end

  def get_vitals(ids, only_active = false, &block)
    yield nil unless ids.present?

    players = Player.or([
      {_id: { '$in' => ids }, 'settings.visibility' => nil},           # Unset
      {_id: { '$in' => ids }, 'settings.visibility' => 0},             # Fully visible
      {_id: { '$in' => followers & ids}, 'settings.visibility' => 1}   # Visible to followers
      ])

    players = players.where(zone_id: { '$ne' => nil }, last_active_at: {'$gt' => Time.now - 6.minutes}) if only_active

    players.fields([:_id, :name, :zone_id]).callbacks(false).all do |players|
      yield players
    end
  end

  def free?
    !self.premium
  end

  def premium?
    self.premium
  end

  def has_key?(key)
    self.keys.include? key
  end

  def calculate_crowns_spent!
    query = { player_id: self.id, amount: { '$lt' => 0 }}
    Transaction.pluck(query, :amount) do |t|
      if t.present?
        update crowns_spent: -t.flatten.sum do |pl|
          EM.add_timer(Deepworld::Env.test? ? 0 : 5.0) do
            check_orders
          end
        end
      end
    end
  end

  # Migrations
  def migrate_reportings_to_mutings
    if @reportings
      mutings = @reportings.inject({}) do |memo, r|
        memo[r[0].to_s] = true
        memo
      end
      self.update({mutings: mutings})
    end

    if @reportings || @reportees
      self.unset(:reportings, :reportings_count, :reportees, :reportees_count)
    end
  end

  def locale
    :en
  end

  def translate(key, args={})
    Loc.translate(locale, key, args)
  end

  alias :t :translate
end
