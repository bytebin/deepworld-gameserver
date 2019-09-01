# General notifications to players
# 1 = System
# 2 = Standard message
# 3 = Emote message
# 4 = Fancy emote message
# 5 = Invisible dialog (floating closable message)
# 6 = Large message
# 9 = Peer status
# 10 = You accomplished something
# 11 = A peer accomplished something
# 12 = You received something
# 13 = Note (with map location)
# 14 = Message & option to share a screenshot
# 16 = Profile alert
# 18 = Death
# 64 = Broadcast code notification
# 333 = all messages sent
# 503 = maintenance
class NotificationMessage < BaseMessage
  data_fields :message, :status
end