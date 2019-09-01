class CommandDirectory
  COMMANDS = {
    1   => 'AuthenticateCommand',
    5   => 'MoveCommand',
    10  => 'InventoryUseCommand',
    11  => 'BlockMineCommand',
    12  => 'BlockPlaceCommand',
    13  => 'ChatCommand',
    14  => 'InventoryMoveCommand',
    16  => 'BlocksRequestCommand',
    18  => 'HealthCommand',
    19  => 'CraftCommand',
    21  => 'BlockUseCommand',
    22  => 'ChangeAppearanceCommand',
    23  => 'ZoneSearchCommand',
    24  => 'ZoneChangeCommand',
    25  => 'BlocksIgnoreCommand',
    26  => 'RespawnCommand',
    27  => 'FollowCommand',
    28  => 'SettingCommand',
    30  => 'EffectCommand',
    31  => 'SpawnCommand',
    32  => 'KillCommand',
    34  => 'RainCommand',
    35  => 'SkillCommand',
    36  => 'HintCommand',
    37  => 'RedeemCommand',
    38  => 'ZoneEntryCommand',
    41  => 'TransactionCommand',
    42  => 'SerendipityCommand',
    43  => 'TransactionRefreshCommand',
    44  => 'StatCommand',
    45  => 'DialogCommand',
    46  => 'EntityUseCommand',
    47  => 'ConsoleCommand',
    49  => 'BlockDirectCommand',
    51  => 'EntitiesRequestCommand',
    52  => 'FacebookCommand',
    54  => 'StatusCommand',
    55  => 'MissiveCommand',
    57  => 'EventCommand',
    58  => 'UploadCommand',
    59  => 'ChangePasswordCommand',
    62  => 'BookmarkCommand',
    63  => 'QuestCommand',
    143 => 'HeartbeatCommand',
    200 => 'GiveCommand',
    203 => 'DayCommand',
    243 => 'RestartCommand',
    254 => 'AdminCommand',
    255 => 'KickCommand'
  }
  DIRECTORY = COMMANDS.inject({}) { |dir, m| dir[m[1]] = m[0]; dir }

  # Get the command based on the id
  def self.[](ident)
    COMMANDS[ident] ? const_get(COMMANDS[ident]) : nil
  end

  # Lookup the identifier for a command, user lowercased symbol representation(:authenticate, :move)
  def self.ident_for(command_name)
    DIRECTORY[command_name.to_s.split('_').collect(&:capitalize).join + 'Command']
  end
end