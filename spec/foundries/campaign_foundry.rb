class CampaignFoundry < BaseFoundry
  def self.build(params = {})
    { ref: 'abc-123', 
      description: "Campaign #{rand(100000)}", 
      items: [1030]}.merge(params)
  end
end
