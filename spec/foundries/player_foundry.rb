class PlayerFoundry < BaseFoundry
  def self.build(params = {})
    params['name'] ||= (Faker::Name.first_name + Faker::Name.last_name)[0..15]
    params['name_downcase'] = params['name'].downcase

    { auth_tokens: [SecureRandom.hex(8), SecureRandom.hex(8)],
      created_at: Time.now,
      last_active_at: Time.now,
      premium: false,
      platform: 'iPad'
      }.merge(params)
  end
end