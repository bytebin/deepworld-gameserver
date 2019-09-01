class Trade

  attr_reader :timeout_at, :state

  def initialize(first_player, second_player, item_code)
    @first_player = first_player
    @second_player = second_player
    @first_item_code = item_code
    @first_item = Game.item(item_code)

    show_quantity_dialog @first_player, @second_player, @first_item_code, true
    state! :offer_quantity
    timeout_in 30.seconds
  end

  def state!(state)
    @state = state
  end

  def continue(player, values)
    case @state
    when :offer_quantity
      if player == @first_player && values.size == 2 && (values.first.is_a?(String) && values.first.match(/^\d+$/))
        quantity = values.first.to_i
        if values.last.match(/give/i)
          give quantity
        else
          offer quantity
          state! :offer_accept
        end
        return
      end
    when :offer_accept
      if player == @second_player && values.size == 0 #1
        #if values.first == 'yes'
          accept_offer
          state! :counteroffer_item
        # else
        #   cancel! @second_player
        # end
        return
      end
    when :counteroffer_item
      if player == @second_player && values.size == 1 && values.first.is_a?(Fixnum)
        @second_item_code = values.first.to_i
        @second_item = Game.item(@second_item_code)
        show_quantity_dialog @second_player, @first_player, @second_item_code, false
        state! :counteroffer_quantity
        return
      end
    when :counteroffer_quantity
      if player == @second_player && values.size == 1 && (values.first.is_a?(String) && values.first.match(/^\d+$/))
        quantity = values.first.to_i
        counter quantity
        state! :counteroffer_accept
        return
      end
    when :counteroffer_accept
      if player == @first_player && values.size == 0 #1
        #if values.first == 'yes'
          finalize
        # else
        #   cancel! @first_player
        # end
        return
      end
    end

    abort!
  end



  def accept_offer
    timeout_in 30.seconds
    @first_player.show_dialog({ 'sections' => [{ 'title' => "#{@second_player.name} accepted your trade request.", 'text' => 'Their offer will be along shortly.' }]})
    @second_player.show_dialog({ 'sections' => [
      { 'title' => "You accepted a trade request for:" },
      item_section(@first_item, @first_item_quantity),
      { 'text' => "Drag the item you'd like to trade to #{@first_player.name}, then select the amount to offer."}
    ]})
  end

  def give(quantity)
    if check_player(@first_player, @second_player, true) && check_item(@first_player, @first_item_code, quantity)
      @first_player.command! GiveCommand, [@second_player.name, @first_item.code, quantity]
      end_trade

      # Track earthbombs
      if @first_item.code == 512 && quantity == 1000
        @first_player.earthbomb @second_player
      end
    end
  end

  def offer(quantity)
    @first_item_quantity = quantity

    if check_item(@first_player, @first_item_code, quantity)
      min_spawn_distance = 10
      if @first_player.away_from_spawn?(min_spawn_distance) && @second_player.away_from_spawn?(min_spawn_distance)
        if @second_player.accepts_trade?(@first_player)
          if check_player(@first_player, @second_player)
            # Inform first player that their proposal was submitted
            sections = [{ 'title' => 'Your request to trade has been sent:' }, item_section(@first_item, @first_item_quantity)]
            @first_player.show_dialog({ 'sections' => sections }, false)

            # Ask second player if they want to be involved in the trade
            @second_player.join_trade(self)
            show_request_dialog
          end
        else
          @first_player.alert "#{@second_player.name} is not accepting trades right now."
          end_trade
        end
      else
        @first_player.alert "Trades must be performed at least #{min_spawn_distance} blocks away from spawn."
        end_trade
      end
    end
  end

  def counter(quantity)
    @second_item_quantity = quantity

    if check_player(@second_player, @first_player, true)
      if check_item(@second_player, @second_item_code, quantity)
        # Inform second player that their counteroffer was submitted
        sections = [{ 'title' => 'Your trade offer has been sent:' }, item_section(@second_item, @second_item_quantity)]
        @second_player.show_dialog({ 'sections' => sections }, false)

        # Ask first player if the offer is to their liking
        show_confirmation_dialog
      end
    end
  end

  def finalize
    if check_player(@first_player, @second_player, true) && check_player(@second_player, @first_player, true)
      if check_item(@first_player, @first_item_code, @first_item_quantity)
        if check_item(@second_player, @second_item_code, @second_item_quantity)
          # Remove inventories
          @first_player.inv.remove @first_item_code, @first_item_quantity, true
          @second_player.inv.remove @second_item_code, @second_item_quantity, true

          # Add inventories
          @first_player.inv.add @second_item_code, @second_item_quantity, true
          @second_player.inv.add @first_item_code, @first_item_quantity, true

          # Notify
          first_sections = [{ 'title' => "You traded with #{@second_player.name}." }, { 'text' => 'Received:' }, item_section(@second_item, @second_item_quantity)]
          @first_player.show_dialog({ 'sections' => first_sections })
          second_sections = [{ 'title' => "You traded with #{@first_player.name}." }, { 'text' => 'Received:' }, item_section(@first_item, @first_item_quantity)]
          @second_player.show_dialog({ 'sections' => second_sections })

          # Track changes
          @first_player.track_trade @second_player
          @second_player.track_trade @first_player
          @first_player.track_inventory_change :trade, @first_item_code, -@first_item_quantity, nil, @second_player, @second_item_code, @second_item_quantity
          @second_player.track_inventory_change :trade, @second_item_code, -@second_item_quantity, nil, @first_player, @first_item_code, @first_item_quantity

          # Cleanup
          end_trade
        end
      end
    end
  end


  # Dialogs

  def show_quantity_dialog(player, other_player, item_code, is_initial)
    if item = check_item(player, item_code)
      # Load quantity dialog
      #dialog = Marshal.load(Marshal.dump(Game.config.dialogs.trade)) # Recursively dup it with marshal
      dialog = Hashie::Mash.new(YAML.load(%{
        sections:
          - title: 'Trade with player'
          - text: Quantity
            input:
              type: text select
              options: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '15', '20', '25', '30', '40', '50', '75', '100', '200', '500', '1000', '5000', '10000', '25000', '100000']
              key: quantity
          - input:
              type: text select
              options: ['Request trade', 'Give freely']
              key: type
      }))

      dialog.sections[0].title = "Trade with #{other_player.name}"

      # Only show quantity options that player has enough of
      dialog.sections[1].input.options.reject!{ |o| o.to_i > player.inv.quantity(item_code.to_s) }
      dialog.sections[1].text = "Quantity of #{item.title.downcase} to trade:"
      dialog.sections.pop unless is_initial

      player.show_dialog(dialog, true, { type: :trade })
      timeout_in 10.seconds
    end
  end

  def show_request_dialog
    sections = []

    sections << { 'title' => "#{@first_player.name} would like to trade:" }
    sections << item_section(@first_item, @first_item_quantity)
    sections << { 'text' => "Are you interested?" }

    @second_player.show_dialog({ 'sections' => sections, 'actions' => 'yesno' }, true, { type: :trade })
    timeout_in 10.seconds
  end

  def show_confirmation_dialog
    sections = []

    sections += item_sections("#{@second_player.name} has offered:", @second_item, @second_item_quantity, @first_item, @first_item_quantity, 'For your:')
    sections << { 'title' => "Do you accept this trade?" }

    @first_player.show_dialog({ 'sections' => sections, 'actions' => 'yesno' }, true, { type: :trade })
    timeout_in 10.seconds
  end

  def item_section(item, quantity)
    { 'image' => "inventory/#{item.id}", 'title' => ' ', 'text' => "#{quantity} x #{item.title}", 'text-color' => '363333' }
  end

  def item_sections(title, first_item, first_quantity, second_item, second_quantity, interstitial)
    [
      { 'title' => title },
      item_section(first_item, first_quantity),
      { 'title' => interstitial },
      item_section(second_item, second_quantity)
    ]
  end

  def choice(yesno)
    { 'title' => yesno.capitalize, 'text-color' => '4444ff', 'choice' => yesno.downcase }
  end




  # Checks & validations

  def check_item(player, item_code, minimum_quantity = 1)
    if item = Game.item(item_code)
      return item if player.inv.quantity(item.code.to_s) >= minimum_quantity
    end

    player.alert "You do not have enough inventory to complete the trade."
    other_player = player == @first_player ? @second_player : @first_player
    other_player.alert "#{player.name} cannot complete the trade."
    end_trade
    false
  end

  def check_player(player, other_player, allow_current_trade = false)
    if other_player && !other_player.disconnected
      if allow_current_trade || !other_player.trade
        return true
      end
    end

    player.alert "#{other_player.name} cannot trade right now - try again in a minute."
    end_trade
    false
  end

  def between?(first_player, second_player)
    @first_player == first_player && @second_player == second_player
  end

  def started_by?(player)
    @first_player == player
  end

  def get_other(player)
    player == @first_player ? @second_player : @first_player
  end



  # Timeouts & abort

  def timeout_in(duration)
    @timeout_at = Time.now + duration
  end

  def timeout_if_necessary
    timeout! if Time.now > @timeout_at
  end

  def timeout!
    if ![:offer_quantity].include?(@state)
      @first_player.try :show_dialog, { 'sections' => [{ 'text' => "Your trade with #{@second_player.name} was cancelled." }]}
      @second_player.try :show_dialog, { 'sections' => [{ 'text' => "Your trade with #{@first_player.name} was cancelled." }]}
    end
    abort! ''
  end

  def cancel!(canceller)
    canceller.alert "You cancelled the trade."

    other = get_other(canceller)
    other.alert "#{canceller.name} cancelled the trade."

    end_trade
  end

  def abort!(msg = nil)
    msg ||= "Sorry, there was an error with the trade."
    if msg.present?
      @first_player.try :alert, msg
      @second_player.try :alert, msg
    end
    end_trade
  end

  def end_trade
    @first_player.try :end_trade, self
    @second_player.try :end_trade, self
  end

end
