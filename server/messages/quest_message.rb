class QuestMessage < BaseMessage
  configure collection: true
  data_fields :details, :status
end