class DialogMessage < BaseMessage
  configure compression: true
  data_fields :dialog_id, :config
end

