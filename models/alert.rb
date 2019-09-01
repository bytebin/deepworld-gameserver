class Alert < MongoModel
  fields [:key, :message, :level]
  fields [:server_id, :zone_id, :player_id]
  fields :created_at, Time

  def self.create(key, level, message, details = nil, &block)
    details = {
      key: key,
      level: level,
      message: message,
      created_at: Time.now,
      resolutions_sent_at: Time.now
    }.merge(details || {})

    super(details) do |alert|
      yield alert if block_given?
    end
  end
end