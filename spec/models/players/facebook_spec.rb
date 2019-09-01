require 'spec_helper'

describe Players::Facebook do

  before(:each) do
    with_a_zone
    with_2_players
    [@one, @two].each{ |pl| pl.stub(:publish_initial_graph_actions).and_return(true) }
  end

  describe 'connecting' do

    it 'should assign a facebook ID' do
      @one.stub(:facebook_graph).and_yield('id' => 'id')
      command! @one, :facebook, ['connect', 'token']
      eventually do
        @one.facebook_id.should eq 'id'
      end
    end

    it 'should gift 25 crowns for connecting' do
      @one.stub(:facebook_graph).and_yield('id' => 'id')
      command! @one, :facebook, ['connect', 'token']
      command! @one, :facebook, ['connect', 'token']
      reactor_wait
      @one.crowns.should eq 25
    end

    it 'should error if facebook ID is already in use' do
      PlayerFoundry.create facebook_id: 'id'

      @one.stub(:facebook_graph).and_yield('id' => 'id')
      command! @one, :facebook, ['connect', 'token']
      eventually do
        @one.facebook_id.should be_nil
        receive_msg!(@one, :notification).data.to_s.should =~ /already/
      end
    end

    it 'should error if no facebook ID can be retrieved' do
      @one.stub(:facebook_graph).and_yield('error' => 'nothing to see here')
      command! @one, :facebook, ['connect', 'token']
      eventually do
        @one.facebook_id.should be_nil
        receive_msg!(@one, :notification).data.to_s.should =~ /connecting/
      end
    end

  end

  describe 'permissions' do

    before(:each) do
      @one.stub(:should_request_facebook_actions?).and_return(true)
      @one.stub(:play_time).and_return(10.hours.to_i)
      @one.facebook_id = '123'
    end

    it 'should request facebook permissions' do
      @one.facebook_permission?('publish_actions').should be_false
      @one.should_request_facebook_permissions?.should be_true
    end

    it 'should not request facebook permissions if already present' do
      @one.facebook_permissions['publish_actions'] = Time.now
      @one.should_request_facebook_permissions?.should be_false
    end

    it 'should reward crowns after authorizing publish_actions permissions' do
      @one.stub(:facebook_graph).and_yield({ 'data' => [{ 'basic_info' => 1, 'publish_actions' => 1 }] })
      send_and_respond_to_permissions_dialog
      @one.crowns.should eq 25
    end

    xit 'should first request connect and then permissions if player is not connected yet' do
      @one.facebook_id = nil
      send_and_respond_to_permissions_dialog false

      # Client gets event
      receive_msg!(@one, :event).data.should eq ['playerWantsFacebookConnect', nil]

      # Client responds with token
      @one.stub(:facebook_graph).and_yield('id' => 'id')
      command! @one, :facebook, ['connect', '123']

      # Client should immediately get permission event
      receive_msg!(@one, :event)
      receive_msg!(@one, :event)
      receive_msg!(@one, :event).data.should eq ['requestFacebookPermissions', 'publish_actions']
    end

    it 'should not reward crowns if publish_actions permission is not present' do
      @one.stub(:facebook_graph).and_yield({ 'data' => [{ 'basic_info' => 1 }] })
      send_and_respond_to_permissions_dialog
      @one.crowns.should eq 0
    end

    it 'should not reward twice for publish_actions permission' do
      @one.stub(:facebook_graph).and_yield({ 'data' => [{ 'basic_info' => 1, 'publish_actions' => 1 }] })
      send_and_respond_to_permissions_dialog
      command! @one, :facebook, ['permissions', '123']
      @one.crowns.should eq 25
    end

    def send_and_respond_to_permissions_dialog(expect_permissions_event = true)
      @one.stub(:should_request_facebook_permissions?).and_return(true)
      @one.request_facebook_actions

      # Respond to dialog affirmatively
      dialog_id = receive_msg!(@one, :dialog).data.first
      command! @one, :dialog, [dialog_id, []]

      if expect_permissions_event
        # Event should be fired
        event = receive_msg!(@one, :event)
        event.data.should eq ['requestFacebookPermissions', 'publish_actions']

        # Client responds
        command! @one, :facebook, ['permissions', '123']
      end
    end

  end

  describe 'invites' do

    def invite!(ids = '%5B0%5D=100002513465484&to%5B1%5D=100000585448240')
      @one.facebook_invite "fbconnect://success?request=710157248998563&to#{ids}"
    end

    it 'should create invites' do
      invite!
      eventually do
        invites = collection(:invite).find.to_a
        invites.size.should eq 2
        invites[0]['player_id'].should eq @one.id
        invites[0]['invitee_fb_id'].should eq '100002513465484'
      end
    end

    it 'should not create more than one invite per player' do
      invite!
      reactor_wait
      invite!
      invite! '%5B0%5D=1234567890'
      eventually do
        collection(:invite).find.to_a.size.should eq 3
      end
    end

    it 'should create a missive as a result of an invite if an existing player has the invited facebook ID' do
      @two.update facebook_id: '100002513465484'

      invite!
      eventually do
        invite = collection(:invite).find.to_a.first
        invite['linked'].should eq 'e'

        missive = collection(:missive).find.to_a.first
        missive['player_id'].should eq @two.id
        missive['message'].should =~ /help/
      end
    end

    it 'should create a missive on Facebook connect if matching the invited facebook ID' do
      invite!
      reactor_wait
      reactor_wait
      invite = collection(:invite).find.to_a.first
      invite['linked'].should be_false
      collection(:missive).find.to_a.should be_blank

      @two.stub(:facebook_graph).and_yield('id' => '100002513465484')
      @two.facebook_connect '1234'
      reactor_wait

      missive = collection(:missive).find.to_a.first
      missive['player_id'].should eq @two.id
      missive['message'].should =~ /help/

      eventually do
        invite = collection(:invite).find.to_a.find{ |inv| inv['invitee_fb_id'] == '100002513465484' }
        invite['linked'].should eq 'n'
      end
    end
  end
end
