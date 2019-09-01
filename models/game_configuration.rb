class GameConfiguration
  extend Forwardable
  def_delegators :@base, :entities, :damage, :hints, :dialogs, :shop

  CONFIG_KEY = 'game'
  VERSION_CONFIG_KEY = 'config_versioned'

  attr_accessor :base, :base_versioned, :products, :timestamp
  attr_accessor :items, :items_by_code, :items_by_category, :items_by_use, :wardrobe_items, :wardrobe_panel, :hidden_items, :items_by_group, :item_codes_by_group, :items_by_material, :test, :effects
  attr_accessor :achievements, :milestones, :orders, :quests, :daily_bonuses, :wardrobe, :client_version

  def self.packed_version
    '3.0.0'
  end

  def initialize
    @test                 = {}
    @items                = {}
    @items_by_code        = {}
    @wardrobe_items       = []
    @hidden_items         = []
    @items_by_group       = {}
    @item_codes_by_group  = {}
    @items_by_material    = {}
    @items_by_category    = {}
    @items_by_use         = {}
    @achievements         = {}
    @achievements_by_type = {}

    Configuration.where(type: 'config').all do |configs|
      # Pull out main config
      main_config = configs.find{ |cfg| cfg.key == 'config' }
      raise "No game configuration found" unless main_config.present?

      # Post-processing
      main_config = configure_achievements!(main_config.data)
      @base = Hashie::Mash.new(main_config)
      @base.freeze
      @base.items.each_pair { |key, item| configure_item!(key, item) }
      @base.entities.each_pair { |key, item| configure_entity!(key, item) }

      version_config = configs.find{ |cfg| cfg.key == 'config_versioned' }.try(:data)
      cache_versions version_config

      @timestamp = @base.timestamp
      @orders = @base.orders

      @quests = @base.quests
      @quests.details.each_pair do |quest_id, quest|
        quest.id = quest_id
      end

      @daily_bonuses = @base.daily_bonuses
      @milestones = @base.milestones
      @effects = @base.emitters
      @wardrobe = @base.wardrobe
      @wardrobe_panel = @base.wardrobe_panel
      @client_version = @base.client_version

      refresh_products do
        refresh_shop do
          yield self if block_given?
        end
      end

      report! if ENV['STATS']
    end
  end

  def [](key)
    @base[key.to_s]
  end

  def configure_item!(key, item)
    item = Hashie::Mash.new(item)

    # Additional fields
    item.use ||= {}
    item.damage_range ||= item['damage range']
    item.minigame = item.use.minigame
    item.karma ||= 0
    item.track = item.karma < -2 || (item.rarity || 0) >= 3
    item.layer_code = { 'front' => FRONT, 'back' => BACK, 'base' => BASE, 'liquid' => LIQUID }[item.layer]

    @items[key] = item
    @items_by_code[item.code] = item

    # Grouping
    if item.group
      @items_by_group[item.group] ||= []
      @items_by_group[item.group] << item

      @item_codes_by_group[item.group] ||= []
      @item_codes_by_group[item.group] << item.code.to_s
    end

    # Use
    if item.use
      item.use.keys.each do |use|
        @items_by_use[use] ||= []
        @items_by_use[use] << item
      end
    end

    # Material
    if item.material
      @items_by_material[item.material] ||= []
      @items_by_material[item.material] << item
    end

    # Wardrobe
    if item.wardrobe
      @wardrobe_items << item
    end

    # Hidden
    if item['inventory type'] == 'hidden'
      @hidden_items << item.code
    end
  end

  def configure_entity!(key, entity)
    entity.name = key
  end

  def refresh_products
    Product.enabled.all do |products|
      @products = products
      yield if block_given?
    end
  end

  def refresh_shop
    GameStat.where(key: /^shop/).all do |shop_stats|
      @shop_stats = (shop_stats || []).inject({}) do |hash, shop_stat|
        hash[shop_stat.key.sub(/shop_section_/, '')] = shop_stat.data
        hash
      end
      yield if block_given?
    end
  end

  def items_by_category(category)
    @items_by_category[category] ||= item_search(/^#{category}/)
  end

  def item(item_name_or_code)
    i = item_name_or_code.is_a?(Fixnum) ? @items_by_code[item_name_or_code] : @items[item_name_or_code]
    i ||= @items_by_code[item_name_or_code.to_i]
    i || default_item
  end

  def item_exists?(item_name_or_code)
    i = item(item_name_or_code)
    i.present? && i.code > 0
  end

  def default_item
    @default_item ||= item(0)
  end

  def item_search(regex)
    @items.select{ |k,v| k.match regex }
  end

  def item_code(item_name)
    @items[item_name].try :code
  end

  def whole_items
    @whole_items ||= @items.values.select{ |i| i.whole }.collect(&:code)
  end

  def shelter_items
    @shelter_items ||= @items.values.select{ |i| i.shelter }.collect(&:code)
  end

  def achievements_by_type(type)
    @achievements_by_type[type]
  end

  def cache_versions(data)
    @base_versioned = Hashie::Mash.new(data)

    cfg = dupe!(self.base)
    cfg.delete 'orders'
    cfg.delete 'quests'
    cfg.delete 'daily_bonuses'
    if cfg['shop']
      cfg['shop'].delete 'sales'
      cfg['shop']['items'].reject! do |item|
        (item['available_after'] && Time.now < Time.new(Time.now.year, item['available_after'][0], item['available_after'][1])) ||
        (item['available_until'] && Time.now > Time.new(Time.now.year, item['available_until'][0], item['available_until'][1]))
      end
    end
    cfg_packed = false

    cfg['ui'] ||= {}
    cfg['ui']['quests'] = true

    @versions = { '0.0.1' => cfg }
    version_numbers = @base_versioned.keys.sort_by{ |v| Versionomy.parse(v) }

    version_numbers.each do |version|
      parsed_version = Versionomy.parse(version)

      cfg = @versions[version] = dupe!(cfg)
      vcfg = dupe!(@base_versioned[version])

      vcfg.each_pair do |key, vcfg_section|
        cfg[key] ||= {}
        vcfg_section.keys.each{ |k| cfg[key].delete k }
        cfg[key].merge! vcfg_section
      end
    end

    @versions.each_pair do |version, cfg|
      process_packing! cfg, Versionomy.parse(version) >= Versionomy.parse(self.class.packed_version)
    end
  end

  def base_config_for_version(platform, version)
    version = Versionomy.parse(version || '0.0.1')
    cfg_version = @versions.keys.map{ |v| Versionomy.parse(v) }.select{ |v| version >= v }.sort.last.to_s
    @versions[cfg_version]
  end

  def process_packing!(cfg, should_pack)
    # Unity-specific changes
    if should_pack
      # Replace normal items with mapped items
      cfg['items'] = cfg.delete('packed_items') || {}
      cfg['item_key_map'] = cfg.delete('packed_item_keys') || {}
    else
      # Kill mapped items
      cfg.delete 'packed_items'
      cfg.delete 'packed_item_keys'
    end
  end

  def data_async(player, &block)
    raise "No callback" unless block_given?
    EventMachine.defer(proc { data(player) }, block)
  end

  def data(player, allow_for_tests = false)
    cfg = nil

    begin
      start_time = Time.now
      Game.add_benchmark :game_configuration_data do
        return {} if (Deepworld::Env.test? && !allow_for_tests)

        # Clone config
        cfg = dupe!(base_config_for_version(player.platform, player.current_client_version))

        # Get rid of items not yet available (in prod)
        if Deepworld::Env.production?
          pre_unavail_ids = cfg["items"].keys.dup
          cfg["items"].reject!{ |k,v| v["available_after"] && Time.now < v["available_after"] }
          p "Removed unavailable items: #{pre_unavail_ids - cfg["items"].keys.dup}"
        end

        # Merge products into shop
        shop = cfg['shop'] ||= {}
        product_hash = Product.shop_hash(@products, player)
        shop.merge! product_hash

        if shop['sections']
          if player.v3?
            # Add products to home section of shop
            home_items = product_hash['currency'].values.sort_by{ |v| v['quantity'] || 0 }.map{ |v| v['identifier'] }
            shop['sections'][0]['name'] = 'Home'
            shop['sections'][0]['items'] = home_items
          end

          # Add top items to shop sections
          shop['sections'].each do |section|
            section['top_items'] = @shop_stats[section['key']]
          end

          if player.free?
            if player.v2?
              shop['sections'][0]['items'].unshift 'starter-pack'
              shop['sections'][0]['items'].unshift 'premium-pack'
            end
          end
        end

        # Set graphics quality default
        begin
          if cfg['dialogs']
            cfg['dialogs']['settings_v3'][1]['settings'].find{ |s| s['key'] == 'graphicsQuality' }['default'] = player.default_graphics_quality

            # Swap settings panes 0 and 1 for desktop
            unless player.touch?
              zero = cfg['dialogs']['settings_v3'][0]
              one = cfg['dialogs']['settings_v3'][1]
              cfg['dialogs']['settings_v3'][0] = one
              cfg['dialogs']['settings_v3'][1] = zero
            end
          end
        rescue
        end

        player.zone.update_player_configuration player, cfg if player.zone
      end

      p "[GameConfiguration] Config took #{((Time.now - start_time)*1000).to_i}ms" if Deepworld::Env.development?

      cfg
    rescue
      p "Game configuration error: #{$!}, #{$!.backtrace.first(5)}"
      raise
    end
  end

  def achievement_types
    @achievements_by_type.keys
  end

  def mutable_dialog(key)
    Marshal.load(Marshal.dump(@base.dialogs[key]))
  end



  private

  def configure_achievements!(data)
    @achievements = Hashie::Mash.new(dupe!(data['achievements']))
    @achievements_by_type = @achievements.inject({}) do |memo,(k,v)|
      memo[v['type']] ||= {}
      memo[v['type']][k] = v
      memo
    end

    # Rewrite client version of achievements
    data['achievements'] = @achievements.inject({}) do |memo,(k,v)|
      memo[k] = v.slice('base', 'directions', 'description', 'survival_requirement', 'tier', 'hidden', 'previous')
      memo
    end

    data
  end

  def dupe!(data)
    # msgpack is way faster!
    #Marshal.load(Marshal.dump(data))
    MessagePack.unpack(data.to_msgpack)
  end

  def report!
    cfg = dupe!(self.base)
    cfg.delete 'orders'
    cfg.delete 'spine'

    verbose_packed = MessagePack.pack(cfg)
    verbose_packed_gzipped = Zlib::Deflate.deflate(verbose_packed, Zlib::BEST_SPEED)
    verbose_json = JSON.generate(cfg)
    verbose_json_gzipped = Zlib::Deflate.deflate(verbose_json, Zlib::BEST_SPEED)

    cfg.items = @packed_items
    cfg.item_key_map = @packed_item_keys

    mapped_packed = MessagePack.pack(cfg)
    mapped_packed_gzipped = Zlib::Deflate.deflate(mapped_packed, Zlib::BEST_SPEED)
    mapped_json = JSON.generate(cfg)
    mapped_json_gzipped = Zlib::Deflate.deflate(mapped_json, Zlib::BEST_SPEED)

    p "Config stats:"
    p "Verbose / msgpacked: #{verbose_packed.bytesize/1000}k packed, #{verbose_packed_gzipped.bytesize/1000}k gzipped"
    p "Verbose / json: #{verbose_json.bytesize/1000}k packed, #{verbose_json_gzipped.bytesize/1000}k gzipped"
    p "Mapped / msgpacked: #{mapped_packed.bytesize/1000}k packed, #{mapped_packed_gzipped.bytesize/1000}k gzipped"
    p "Mapped / json: #{mapped_json.bytesize/1000}k packed, #{mapped_json_gzipped.bytesize/1000}k gzipped"
  end

end
