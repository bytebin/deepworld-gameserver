module Players
  module Orders

    def check_orders
      @orders ||= {}

      Game.config.orders.each_pair do |name, details|
        if name != 'all'
          key = details['key']
          current_tier = @orders[key] || 0

          # Get max allowed tier based on order details and "all" details (cross-order requirements)
          max_tier = order_tier(details)

          # If player has advanced tiers, send a message and update orders hash
          if max_tier > current_tier
            @orders[key] = max_tier

            order_updates = { orders: @orders }
            order_updates[:primary_order] = key unless details.hidden

            update order_updates do
              # Send icon update
              update_order_icon

              # Send entity change icon
              change 'ni' => current_order_icon

              # Send notification
              title = current_tier == 0 ? Game.config.orders.all.induction_title : Game.config.orders.all.advancement_title
              text = current_tier == 0 ? details.induction_message : details.advancement_message
              show_dialog [{ 'title' => title }, { 'text' => text }]

              # Notify peers
              peer_msg = current_tier == 0 ? Game.config.orders.all.peer_induction_message : Game.config.orders.all.peer_advancement_message
              notify_peers "#{@name} #{peer_msg} #{name}.", 11 unless details.hidden

              # Create/update order membership doc
              OrderMembership.upsert({ player_id: self.id, order: key }, { tier: max_tier })

              add_xp :order
            end
          end
        end
      end
    end

    def order_tier(details)
      (1..details.tiers.size).to_a.reverse.each do |tier|
        if details.tiers[tier - 1].requirements.all? { |method, requirement|
          m = method.split('/')
          if m.size == 1
            (send(m.first) || 0) >= requirement
          elsif m.size == 2
            vals = send(m.first)
            (vals[m.last] || 0) >= requirement
          end
        }
          return tier
        end
      end

      0
    end

    def update_order_icon
      queue_message EventMessage.new('playerIconDidChange', current_order_icon ? "emoji/#{current_order_icon}" : nil)
    end

    def current_order_icon
      if @primary_order && @orders[@primary_order]
        "orders/#{@primary_order}-#{@orders[@primary_order]}"
      else
        nil
      end
    end

  end
end
