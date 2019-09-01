class Transaction < MongoModel
  fields [:pending, :source, :source_identifier, :description] # Needs to be applied to player on load, source will be "referrel {id}" or referred {id}
  fields [:player_id, :amount, :premium, :item, :created_at, :processing_required]
  fields [:currency, :net_local, :net_usd, :gross_local, :gross_usd]

  def self.item(item_key)
    Game.config.shop.items.detect{ |i| i['key'] == item_key }
  end

  def self.credit(player, amount, source)
    self.create_transaction(player, source, amount)
  end

  def self.debit(player, item, amount)
    self.create_transaction(player, item, -amount)
  end

  # Can be called with a block which will yield a true/false indicating a transaction was applied
  def self.apply_pending(player)
    transaction_types = ['gift', 'admin', 'app store', 'web', 'offer', 'stripe', 'steam', 'fake', 'loot']
    transaction_types += ['referred', 'referral'] if player.premium

    # Look for pending transactions, and apply
    self.where(player_id: player.id, pending: true, source: {'$in' => transaction_types}).all do |transactions|
      if transactions.count > 0
        yield true if block_given?

        # Add up the amounts
        total = transactions.inject(0){ |sum,t| sum + t.amount }

        # See if premium-ness was granted
        premium = transactions.any?{ |t| t.premium }

        # Update transactions to no longer pending
        self.update_all({_id: { '$in' => transactions.collect(&:id)}}, { pending: false }) do
          # Update crowns and send notifications
          player.update(crowns: player.crowns + total) do
            send_notifications(player, transactions)

            # Update premium
            player.convert_premium! false if premium

            # Check for any post-purchase sales
            player.finalize_sales! total
          end
        end
      else
        yield false if block_given?
      end
    end
  end

  def self.send_notifications(player, transactions)
    transactions.group_by(&:source).each_pair do |source, trans|

      # Calculate the sub-total
      total = trans.inject(0){ |sum,t| sum + t.amount }
      description = trans.map(&:description).compakt.uniq

      if trans.any?{ |t| t.premium }
        crowns_msg = total > 0 ? " (along with #{total} crowns)" : nil
        if player.v3?
          player.show_dialog [{ title: "Premium acquired!",
            text: "You are now a premium player. The entire Deepworld universe is yours to explore#{crowns_msg}. Enjoy!" }]
        else
          player.show_dialog [{ title: 'You are now a premium player!',
            list: [{ image: "shop/premium", text: "The entire Deepworld universe is yours\nto explore#{crowns_msg}. Enjoy!" }]}]
        end

      else
        # Notify crowns based on source type
        case source
          when 'referral'
            names = trans.map(&:source_identifier)
            show_crowns_dialog player, 'Referral Bonus:', "#{total} crown referral bonus for #{names.to_sentence}!"
          when 'referred'
            show_crowns_dialog player, 'Referral Bonus:', "#{total} crown bonus from #{trans.first.source_identifier}!"
          when 'app store', 'web', 'stripe', 'steam', 'fake'
            if player.v3?
              show_crowns_dialog player, 'Thank you for your purchase!', "Your #{total} crowns have been added."
            else
              show_crowns_dialog player, 'Crown Purchase:', "Here are your #{total} crowns!"
            end
          when 'gift'
            text = "You've received a gift of #{total} crowns!"
            text += "\n" + description.join("\n") unless description.empty?
            show_crowns_dialog player, 'Crown Gift:', text
          when 'offer'
            text = "You've earned #{total} crowns!"
            text += "\n" + description.join("\n") unless description.empty?
            show_crowns_dialog player, 'Your crowns:', text
        end
      end
    end

    player.queue_message StatMessage.new(['crowns', player.crowns])
  end

  def self.show_crowns_dialog(player, title, message)
    if player.v3?
      player.show_dialog [{ title: title,
        text: message }]
    else
      player.show_dialog [{ title: title,
        list: [{ image: "shop/crowns", text: message }]}]
    end
  end


  private

  def self.create_transaction(player, item, amount, processing_required = false, &block)
    options = {
      player_id: player.id,
      item: item.to_s,
      amount: amount,
      processing_required: processing_required,
      pending: false,
      created_at: Time.now }

    # Create the transaction and add/remove crowns
    self.create(options) do
      player.update(crowns: player.crowns + amount) do
        player.queue_message StatMessage.new(['crowns', player.crowns])
        yield if block_given?
      end
    end
  end
end