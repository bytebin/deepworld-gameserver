# Instruct client to upload something
class UploadMessage < BaseMessage
  data_fields :type, :token, :endpoint
end