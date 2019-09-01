class ConfigurationFoundry < BaseFoundry
  def self.build(params = {})
    { key: 'stuff',
      data: nil
      }.merge(params)
  end
end