# Change which order is displayed
class OrderCommand < BaseCommand

  def execute
    alert Game.config.dialogs.no_order and return unless player.orders.present?
    ranks = %w{None Iron Brass Sapphire Ruby Onyx}

    dialog = Marshal.load(Marshal.dump(Game.config.dialogs.order))
    dialog.sections[0]['input']['options'] = ['None'] + player.orders.keys.map{ |o| o.capitalize }.sort
    dialog.sections += [
      { 'text' => "\nYour ranks:" },
      {
        'text' => player.orders.map{ |o,t| "#{o.capitalize} - #{ranks[t]}" }.join(', '),
        'text-size' => 0.6,
        'text-color' => '999999'
      }
    ]
    player.show_dialog dialog, true do |vals|
      new_order = vals.first == 'None' ? nil : vals.first.downcase

      player.update primary_order: new_order do
        # Send messages
        player.update_order_icon
        player.change 'ni' => player.current_order_icon
      end
    end
  end

end
