class AchievementMessage < BaseMessage
  configure collection: true
  data_fields :key, :points
end