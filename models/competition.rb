class Competition < MongoModel
  fields [:name, :description, :phase, :judges, :nomination_threshold, :max_votes, :max_entries, :participants]
  fields :created_at, Time

  ACTIVE = "active"
  NOMINATION = "nomination"
  JUDGING = "judging"
  FINISHED = "finished"

  attr_reader :last_entry

  def after_initialize
    @phase ||= ACTIVE
    @judges ||= []
    @nomination_threshold ||= 3
    @max_votes ||= 10
    @max_entries ||= 1
    @participants ||= {}
  end

  def setup_zone(zone)
    @zone = zone

    # Get current max entry number
    @last_entry = 0
    entries.each { |e| @last_entry = [@last_entry, e['entry']].max if e['entry'] }

    # Assign entry info to competition protectors
    entries.each do |e|
      if e.player?
        # Entry number
        e['entry'] = (@last_entry += 1) unless e['entry']

        # Player name
        unless e['pn']
          Player.get_name(e.player_id) do |name|
            e['pn'] = name if name.present?
          end
        end

        # Participation
        unless @participants[e.player_id.to_s]
          increment_participation e.player_id.to_s
        end
      end
    end
  end

  def entries
    @entries ||= @zone.meta_blocks.values.select{ |meta| meta.use?('competition') }.randomized
  end

  def increment_participation(player_id)
    inc "participants.#{player_id.to_s}", 1
  end

  def self.entry_title(entry)
    player_name = entry['pn'] || 'Anonymous'
    "Entry ##{entry['entry']}" + (entry['n'] ? ": #{entry['n']} by #{player_name}" : " by #{player_name}")
  end

end