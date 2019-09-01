class ServerFoundry < BaseFoundry
  def self.build(params = {})
    { name: Faker::Name.first_name }
  end
end