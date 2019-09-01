class AccessCodeFoundry < BaseFoundry
  def self.build(params = {})
    { limit: 1,
      redemptions: 0,
      code: 'a' + Deepworld::Token.generate(7)
    }.merge(params)
  end
end
