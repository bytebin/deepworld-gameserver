class ProductFoundry < BaseFoundry
  def self.build(params = {})
    amt = params.delete(:amount) || ((rand(10)+1) * 100)

    { code: Deepworld::Token.generate(10),
      name: "#{amt} crowns",
      crowns: amt,
      cost: (amt * 0.005).ceil - 0.01,
      description: "#{amt} crowns (can be used to obtain private worlds, protectors, and more)",
      enabled: true
      }.merge(params)
  end

  def self.premium!
    self.create({
      code: 'premium',
      name: 'Premium Upgrade',
      cost: 2.99,
      description: 'Experience all Deepworld has to offer with a premium account. Explore new environments, hundreds of different premium worlds, and a wide variety of new skills and achievements.',
      crowns: nil
      })
  end

  def self.crowns!(amt)
    create amount: amt
  end

  def self.shop!
    [premium!, crowns!(100), crowns!(250), crowns!(500), crowns!(1000), crowns!(2000), crowns!(4000)]
  end
end
