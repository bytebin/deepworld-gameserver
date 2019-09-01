class MinigameRecord < MongoModel
  fields [:code, :server_id, :player_id, :zone_id, :position]
  fields [:scoring_event, :range, :countdown_duration, :duration]
  fields [:tool_restriction, :block_restriction, :entity_restriction, :max_deaths, :natural]
  fields [:leaderboard]
  fields :created_at, Time
end
