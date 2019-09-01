class ZoneFoundry < BaseFoundry
  def self.build(params = {})
    data_file = params.delete(:data_path) || 'bunker'
    biome = params[:biome] || 'plain'

    { name: Faker::Name.first_name,
      private: false,
      biome: biome,
      size: Vector2.new(80, 20),
      chunk_size: Vector2.new(20, 20),
      data_path: File.expand_path("../data/#{data_file}.zone", File.dirname(__FILE__)),
      welcome_message: "Welcome to Deepworld",
      paused: false,
      server_id: Game.id,
      entry_code: "z" + Deepworld::Token.generate(6),
      active: true,
      version: 18,
      migrated_version: 18,
      karma_required: biome == 'plain' ? -149 : nil,
      premium: false,
      players_count: 0,
      protection_level: nil,
      file_version: 0,
      file_versioned_at: Time.now
      }.merge(params)
  end

  def self.block_me!(count)
    count.times.collect{[0,300,512,0]}.flatten
  end
end