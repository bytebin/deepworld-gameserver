class RedemptionCodeFoundry < BaseFoundry
  def self.build(params = {})
    { code: Deepworld::Token.generate(8).sub!(/^(a|z)/, 'r'),
      created_at: Time.now,
      auth_token: SecureRandom.hex(8),
      limit: 1
      }.merge(params)
  end
end