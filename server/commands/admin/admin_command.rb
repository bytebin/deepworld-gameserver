class AdminCommand < BaseCommand
  data_fields :key, :data
  admin_required

  def execute
    begin

      case key
      # Toggle godmode
      when 'god'
        player.admin_enabled = data == 1

      # Change block
      when 'change'
        zone.update_block nil, @x, @y, @layer, @item_code, @mod

      # Earthquake
      when 'quake'
        zone.seismic.earthquake! Vector2[data[0].to_i, data[1].to_i]

      # Store new prefab in database
      when 'prefab'
        Prefab.create @data.merge({ created_at: Time.now, creator_id: player.id, active: false })
        alert "Created new prefab #{@data['name']}"

      when 'grow'
        zone.growth_step! [1, data.first.to_i].max

      when 'refill'
        Game.items.values.each do |item|
          if item.ingredients && item.karma > -5
            qty = 500 - player.inv.quantity(item.code)
            player.inv.add item.code, qty, true if qty > 0
          else
            player.inv.add item.code, 1, true if player.inv.quantity(item.code) == 0
          end
        end

      when 'sale'
        case data[0]
        when 'reset'
          player.update sales_shown: {} do
            alert "Sales reset!"
          end
        when 'next'
          player.step_sales true
        else
          player.show_sale_named(data[0])
        end

      when 'clear'
        if item = Game.item(data[0])
          player.confirm_with_dialog "Are you sure you want to clear all #{item.id}?" do
            blocks = zone.find_items(item.code, item.layer_code)
            blocks.each do |bl|
              zone.update_block nil, bl.x, bl.y, item.layer_code, 0, 0
            end
            player.alert "#{blocks.size} blocks cleared!"
          end
        end

      when 'test'
        img = 'http://admintell.napco.com/ee/images/uploads/gamertell/best_buy_cyber_monday_2010_sale_banner_ad.jpg'
        txt = "Unlock your skills with a premium purchase! It's only $2.99 and it comes with 100 free crowns as a bonus!"

        case data[0]
        when 'loot'
          Rewards::Loot.new(player, types: ['treasure+', 'armaments+']).reward!
        when 'clearloot'
          player.loots.clear
          player.last_daily_item_hint_at = nil
          player.xp_daily = {}
          alert "Loots cleared."
        when 'tiny'
          player.small_screen = true
        when 'nohint'
          queue_message EventMessage.new('uiHints', [])
        when 'profilehint'
          queue_message EventMessage.new('uiHints', [{ 'message' => 'Click ok!', 'highlight' => 200 }, { 'message' => 'Click to upgrade your skills', 'highlight' => 22 }, { 'message' => 'Click to open your profile', 'highlight' => 20 }])
        when 'shophint'
          queue_message EventMessage.new('uiHints', [{ 'message' => 'Click buy!', 'highlight' => 200 }, { 'message' => 'Click to buy your home world', 'highlight' => 105 }, { 'message' => 'Click to open the shop', 'highlight' => 100 }])
        when 'currency'
          player.show_dialog({ 'sections' => [{ 'text' => 'Some text!' }, { 'image' => img, 'image_size' => [640, 168], 'image_click' => true }, { 'text' => txt }, { 'image' => 'shop/crowns' }], 'actions' => 'buy', 'event' => ['playerWillBuyCurrency', 'crowns_tier_0'] })
        when 'premium'
          player.show_dialog({ 'sections' => [{ 'image' => 'http://dl.deepworldgame.com/banners/client-premium-v1-half.png', 'image_size' => [637, 215], 'image_click' => true }, { 'text' => txt }], 'actions' => 'buy', 'event' => ['playerWillBuyCurrency', 'premium'], 'width' => 667 })
        when 'shop'
          player.show_dialog({ 'sections' => [{ 'image' => img, 'image_size' => [640*0.8, 168*0.8], 'image_click' => true }, { 'text' => txt }], 'actions' => 'buy', 'event' => ['playerWillBuyItem', 'pandora-pack'] })
        when 'suppress_flight'
          zone.status! :suppress_flight, data[1] ? data[1] == 'true' : true
        when 'suppress_guns'
          zone.status! :suppress_guns, data[1] ? data[1] == 'true' : true
        when 'suppress_mining'
          zone.status! :suppress_mining, data[1] ? data[1] == 'true' : true
        when 'behave'
          zone.ecosystem.behave_all = true
        when 'fertilize'
          zone.growth.fertilize! Vector2[data[1].to_i, data[2].to_i]
        when 'quip'
          data[1].to_i.times do
            player.emote "+1 #{Game.fake(:name)}"
          end
        when 'entered'
          player.event! :entered, Hashie::Mash.new(zone_name: data[1..-1].join(' '))
        end

      when 'validate'
        case data[0]
        when 'meta'
          errs = zone.validate_field_blocks
          if errs.present?
            alert "Found meta errors: #{errs}"
          else
            alert 'Meta blocks OK.'
          end
        end

      when 'quest'
        player.quests.delete data[1]

        case data[0]
        when 'begin'
          player.begin_quest data[1]
        when 'complete'
          player.begin_quest data[1]
          player.complete_quest data[1]
        when 'delete'
          player.quests.delete data[1]
          player.alert "Deleted quest #{data[1]}"
        end

      when 'iap'
        EM.add_timer(0.5) do
          premium = data == "premium"
          crowns = premium ? 100 : data.to_i

          Transaction.create player_id: player.id,
            source: 'fake',
            amount: crowns,
            pending: true,
            created_at: Time.now,
            premium: premium do
              EM.add_timer(1.0) do
                player.queue_message EventMessage.new("closeLastDrawer", nil)
                Transaction.apply_pending player
              end
          end
        end

      when "liquify"
        zone.liquify_air! data[0].to_i

      end
    rescue
      alert $!.message
    end
  end

  def validate
    case key
    when 'change'
      validate_change
    when 'prefab'
      validate_prefab
    end
  end

  def validate_change
    if data.is_a?(Array) && data.size >= 4
      @x = data[0].to_i
      @y = data[1].to_i
      @layer = { 'front' => FRONT, 'back' => BACK, 'base' => BASE, 'liquid' => LIQUID }[data[2]]
      @item_code = data[3].is_a?(Fixnum) || data[3].match(/^\d+$/) ? data[3].to_i : Game.item_code(data[3])
      @mod = data[4].to_i

      @errors << "Invalid layer" and return unless @layer
      @errors << "Invalid item" and return unless @item_code
      @errors << "Invalid mod" and return unless @mod < 32

      return
    end

    @errors << "Please supply: x, y, layer, item/code, mod = 0"
  end

  def validate_prefab
    if data.is_a?(Hash)
      @errors << "Invalid keys" unless @data.keys.sort == ['blocks', 'name', 'size']

      blocks = data['blocks']
      @errors << "Invalid block data" unless blocks.is_a?(Array) && blocks.flatten.all?{ |b| b.is_a?(Fixnum) }

      name = data['name']
      @errors << "Invalid name" unless name.is_a?(String) && name.size < 64

      size = data['size']
      @errors << "Invalid size" unless size.is_a?(Array) && size.size == 2 && size.all?{ |s| s.is_a?(Fixnum) }
    else
      @errors << "Data must be a hash"
    end
  end

  def fail
    alert @errors.join(', ')
  end



end
