require 'spec_helper'

describe PushNotification do

  before(:each) do

  end

  it 'should send push notifications to players' do
    EventMachine::HttpRequest.stub(:post).and_raise 'No HTTPz, brah!'

    with_a_zone
    with_a_player @zone
    PushNotification.create(@one, 'sup brah').should be_true
  end

  it 'should not send push notifications to players who have turned them off' do
    EventMachine::HttpRequest.stub(:post).and_return(true)

    with_a_zone
    with_a_player @zone, settings: { 'pushMessaging' => 1 }
    PushNotification.create(@one, 'sup brah').should be_false
  end

end
