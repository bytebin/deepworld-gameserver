class MissiveFoundry < BaseFoundry
  def self.build(params = {})
    player_id = params[:player_id] || PlayerFoundry.create.id
    creator = PlayerFoundry.create

    { player_id: player_id,
      message: 'Hello world',
      creator_id: creator.id,
      creator_name: creator.name,
      type: 'pm',
      created_at: Time.now,
      read: false
    }.merge(params)
  end
end