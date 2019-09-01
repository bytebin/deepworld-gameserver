# Used for arbitrary console commands
class ConsoleCommand < BaseCommand
  # TODO handle no name for add/remove
  data_fields :command, :params

  COMMAND_MAP = {
    help:  'HelpCommand',
    whelp:  'WorldHelpCommand',
    winfo:  'WorldInfoCommand',
    wrecode:  'WorldRecodeCommand',
    wadd:  'WorldAddCommand',
    wremove:  'WorldRemoveCommand',
    wrename:  'WorldRenameCommand',
    wpvp:  'WorldPvpCommand',
    wpublic:  'WorldPublicCommand',
    wprotected:  'WorldProtectedCommand',
    wenter:  'WorldEnterCommand',
    wmute:  'WorldMuteCommand',
    wban:  'WorldBanCommand',
    wunban:  'WorldUnbanCommand',
    ghelp: 'GuildHelpCommand',
    ginfo: 'GuildInfoCommand',
    ginvite: 'GuildInviteCommand',
    gremove: 'GuildRemoveCommand',
    gleader: 'GuildLeaderCommand',
    gquit: 'GuildQuitCommand',
    chop: 'ChopCommand',
    trading: 'TradingCommand',
    exo: 'ExoCommand',
    team: 'TeamCommand',
    entry: 'EntryCommand',
    construct: 'ConstructCommand',
    say: 'SayCommand',
    think: 'ThinkCommand',
    pm: 'PrivateMessageCommand',
    order: 'OrderCommand',
    skiptut: 'SkipTutorialCommand',
    report: 'ReportCommand',
    mute: 'MuteCommand',
    mutex: 'MutexCommand',
    unmute: 'UnmuteCommand',
    count: 'CountCommand',
    nearest: 'NearestCommand',
    despam: 'DespamCommand',
    redeem: 'RedeemCommand',
    freeze: 'FreezeCommand',
    register: 'RegisterCommand',
    tp: 'TeleportCommand',
    su: 'SummonCommand',
    meta: 'MetaCommand',
    evoke: 'EvokeCommand',
    drain: 'DrainCommand'
  }

  def execute
    cmd = COMMAND_MAP[command.to_sym].constantize
    params = combine_params(cmd.field_length + cmd.optional_field_length)

    if (cmd.field_length..cmd.field_length+cmd.optional_field_length).include?(params.length)
      cmd = player.command!(cmd, params)
      @errors += cmd.errors unless cmd.errors.empty?
    else
      @errors << "Incorrect parameters for #{command}."
    end
  end

  def validate
    @errors << "Invalid command" unless COMMAND_MAP[command.to_sym]
  end

  def fail
    alert @errors.first
  end

  def combine_params(length)
    if params.is_a?(String) || params.length <= length
      return [params].flatten
    else
      length > 1 ? [params.first, params[1..-1].join(' ')] : [params.join(' ')]
    end
  end
end
