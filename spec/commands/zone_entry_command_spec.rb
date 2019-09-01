require 'spec_helper'

describe ZoneEntryCommand do
  it 'should not let you leave hell' do
    hell = ZoneFoundry.create(name: 'Hell')
    not_hell = ZoneFoundry.create

    @one, @o_sock = auth_context(hell)
    
    enter_zone not_hell.entry_code
    
    receive_message[:message].should eq "Sorry, you're not allowed out of Hell."
    PlayerFoundry.reload(@one).zone_id.should eq hell.id
  end

  context 'With a player and zone' do
    before(:each) do
      @current_zone = ZoneFoundry.create
      @zone = ZoneFoundry.create(private: true)
      @one, @o_sock = auth_context(@current_zone)
    end
  
    it 'should not let you enter an unknown zone' do
      enter_zone 'junkypants'

      receive_message[:message].should eq "Can't find a zone for that code."
      PlayerFoundry.reload(@one).zone_id.should eq @current_zone.id
    end

    it 'should not let you enter your existing zone' do
      enter_zone @current_zone.entry_code

      receive_message[:message].should eq "You are already in #{@current_zone.name}."
      PlayerFoundry.reload(@one).zone_id.should eq @current_zone.id
    end

    it 'should not let you transfer to a zone that you are the owner of' do
      @zone.add_owner @one

      enter_zone @zone.entry_code
      receive_message[:message].should eq "You're already a member of #{@zone.name}.\nFind yourself a teleporter."
    end

    it 'should not let you transfer to a zone that you are a member of' do
      @zone.add_member @one

      enter_zone @zone.entry_code
      receive_message[:message].should eq "You're already a member of #{@zone.name}.\nFind yourself a teleporter."
    end

    it 'should make you the owner if youre the first to enter a zone' do
      enter_zone @zone.entry_code

      msg = receive_message.should be_message(:kick)
      ZoneFoundry.reload(@zone).owners.should include(@one.id)
    end

    it 'sould make you a member if youre not the first to enter a zone' do
      @zone.add_owner PlayerFoundry.create(name: 'SomeOtherDude')
      enter_zone @zone.entry_code

      msg = receive_message.should be_message(:kick)
      ZoneFoundry.reload(@zone).members.should include(@one.id)
    end
  end
  
  # Helpers

  def enter_zone(code)
    Message.new(:zone_entry, [code]).send(@o_sock)
  end

  def receive_message
    Message.receive_one(@o_sock, only: [:kick, :notification])
  end
end