class AchievementProgressMessage < BaseMessage
  configure collection: true
  data_fields :key, :progress
end