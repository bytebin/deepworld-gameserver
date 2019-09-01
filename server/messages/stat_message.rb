class StatMessage < BaseMessage
  configure collection: true
  data_fields :key, :value
end