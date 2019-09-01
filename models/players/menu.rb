module Players
  class Menu

    def initialize(requester, subject_name)
      @requester = requester

      if subject = @requester.zone.find_player(subject_name)
        present subject
      else
        Player.named(subject_name, fields: [:name, :zone_id, :zone_name, :last_active_at, :settings, :followers]) do |subject|
          if subject.present?
            present subject
          else
            @requester.alert "Player #{subject_name} not found."
          end
        end
      end
    end

    def present(subject)
      begin
        sections = []

        if visibility = subject.visibility_description(@requester)
          sections << { 'text' => visibility }
          if subject.active_recently? && subject.zone_id != @requester.zone_id
            sections << { 'text' => "Goto #{subject.zone_name}", 'choice' => 'visit' }
          end
        end

        if @requester.followed?(subject)
          sections << { 'text' => "Message", 'choice' => 'message' }
        end

        follow = @requester.follows?(subject) ? 'Unfollow' : 'Follow'
        mute = @requester.has_muted?(subject) ? 'Unmute' : 'Mute'
        sections += [
          { 'text' => follow, 'choice' => follow.downcase },
          { 'text' => mute, 'choice' => mute.downcase },
          { 'text' => 'Report', 'choice' => 'report' }
        ]

        dialog = { 'title' => subject.name, 'sections' => sections }

        @requester.show_dialog dialog, true do |resp|
          case resp.first
          when 'visit'
            if subject.visible_to_player?(@requester)
              @requester.send_to subject.zone_id
            end
          when 'message'
            # Todo
          when 'follow'
            @requester.follow subject
          when 'unfollow'
            @requester.unfollow subject
          when 'mute'
            @requester.mute! subject
          when 'unmute'
            @requester.unmute! subject
          when 'report'
            # Todo
          end
        end
      rescue
        p "[Menu] Error: #{$!}"
      end
    end

  end
end