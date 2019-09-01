class GuildFoundry < BaseFoundry
  def self.build(params = {})
    params[:zone_id] = ZoneFoundry.create.id unless params.has_key?(:zone_id)

    { name: (Faker::Name.first_name + Faker::Name.last_name)[0..15],
      short_name: ('a'..'z').to_a.random(3).join,
      position: Vector2.new(0, 0)
      }.merge(params)
  end
end
