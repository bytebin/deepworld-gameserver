module Players
  module Sales

    SALE_INTERVAL = 60*60

    def step_sales(force = false)
      @sale_step ||= 15

      if Time.now > self.next_sale_step_at || force
        @next_sale_step_at = Time.now + @sale_step

        if can_view_sales? && (force || Time.now > self.last_sale_at + SALE_INTERVAL)
          show_next_sale
        end
      end
    end

    def next_sale_step_at
      @next_sale_step_at ||= Time.now + @sale_step
    end

    def can_view_sales?
      v2? &&
        !zone.tutorial? &&
        session_play_time > (Deepworld::Env.development? ? 0 : 90) &&
        Time.now > last_damaged_at + 20.seconds
    end

    def show_next_sale
      set_sales_segments!

      if cfg = get_next_sale(self.last_sale_at)
        show_sale cfg
      end
    end

    def show_sale_named(name)
      if cfg = Game.config.shop.sales.periodic_items.find{ |i| i['key'] == name }
        show_sale cfg
        true
      else
        false
      end
    end

    def show_sale(cfg)
      sales_shown[cfg['key']] = (sales_shown[cfg['key']] || 0) + 1

      update last_sale_at: Time.now, sales_shown: sales_shown do |pl|
        image = small_screen? ? cfg.tiny_image : cfg.image
        image_size = small_screen? ? cfg.tiny_image_size : cfg.image_size
        image ||= cfg.image
        image_size ||= cfg.image_size

        show_sales_dialog image, image_size, cfg.text, cfg.action[0], cfg.action[1]
      end
    end

    def set_sales_segments!
      Game.config.shop.sales.segments.each do |name, options|
        segment! name, options unless segment(name)
      end
    end

    def get_next_sale(previous_last_sale_at)
      Game.config.shop.sales.periodic_items.find do |item|
        delay = item.delay || (3600*24)

        (Time.now > previous_last_sale_at + delay) &&
        (!item.segment || segment(item.segment[0]) == item.segment[1]) &&
        (!item.requirements || item.requirements.all?{ |req| send("#{req}?") }) &&
        (!item.available_after || Time.now.utc >= Time.utc(Time.now.year, item.available_after[0], item.available_after[1], item.available_after[2])) &&
        (!item.available_until || Time.now.utc <= Time.utc(Time.now.year, item.available_until[0], item.available_until[1], item.available_until[2])) &&
        ((sales_shown[item['key']] || 0) < (item.recur || 1))
      end
    end

    def show_sales_dialog(image, image_size, text, action_type, action_key)
      event = case action_type
      when 'currency', 'premium' then 'playerWillBuyCurrency'
      when 'shop' then 'playerWillBuyItem'
      end

      sections = [{ 'image' => image, 'image_size' => image_size, 'image_click' => true }, { 'text' => text }]
      show_dialog({ 'sections' => sections, 'actions' => 'buy', 'event' => [event, action_key], 'width' => small_screen? ? 480 : 680 })
    end

    def finalize_sales!(crowns_purchased = 0)
      # Prompt for starter pack
      if crowns_purchased > 0 && Time.now - last_sale_at < 5.minutes && segment('free_account') == 'starter'
        queue_message EventMessage.new('playerWillBuyItem', 'starter-pack')
      end
    end

  end
end
