# Console command: set whether or not players can trade with you
class TradingCommand < BaseCommand

  data_fields :enabled

  def execute
    is_trading = enabled.downcase == 'on'
    player.update_setting 'trading', is_trading
    player.alert "You are #{is_trading ? 'now' : 'no longer'} accepting trades."
  end

  def validate
    unless %w{on off}.include?(enabled)
      @errors << msg = "Please specify 'on' or 'off'."
      notify msg
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
