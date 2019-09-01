module Players
  module Reporting

    def report!(reportee)
      if @last_reported_at && Time.now < @last_reported_at + 30.seconds
        alert "Please do not spam reports." and return
      end

      chats = zone.recent_chats.dup
      if chats.any?{ |ch| ch[0] == reportee.id }
        # Reject private chats to others
        chats.reject!{ |ch| ch[3].present? && ch[3] != self.id }

        saved_chats = chats.map do |ch|
          [ch[0], ch[2], ch[4].to_i]
        end
        PlayerReport.create reportee_id: reportee.id,
          reporter_id: self.id,
          zone_id: zone.id,
          created_at: Time.now,
          chats: saved_chats,
          vote_count: 0,
          closed: false do
            alert "Your report has been submitted."
            @last_reported_at = Time.now
        end
      else
        alert "Player '#{reportee.name}' has not chatted recently."
      end
    end
  end
end