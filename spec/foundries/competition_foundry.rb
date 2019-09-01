class CompetitionFoundry < BaseFoundry
  def self.build(params = {})
    { name: 'Competition' }.merge(params)
  end
end