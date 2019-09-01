require 'spec_helper'

describe RedemptionCode do
  before(:each) do
    @redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 }, wardrobe: ['1333'], appearance:  { 'hg' => 'avatar/helmet', 'hg*' => 'ffffff' })
  end

  it 'should render the correct notification content for a redemption' do
    @redemption.to_notification.should == {sections: [{title: 'You received:', list: [ {item: '1024', text: 'Pickaxe x 3'}, {item: '1333', text: 'Onyx Helmet x 1'} ] } ] }
  end
end