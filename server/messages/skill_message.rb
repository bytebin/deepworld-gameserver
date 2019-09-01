class SkillMessage < BaseMessage
  configure collection: true
  data_fields :name, :level
end