require 'spec_helper'

describe EntityStatusMessage do
  before(:each) do
    with_a_zone
  end

  it 'should send me a message with existing entities' do
    @one, @o_sock, @o_messages = auth_context(@zone)
    @two, @t_sock, @t_messages = auth_context(@zone)
    @dude, @d_sock, @d_messages = auth_context(@zone)

    @d_messages.should be_message(:entity_status, :entity_position)
    @d_messages.first[:name].should eq [@one.name, @two.name]
    one_cfg = @d_messages.first[:details].first
    one_cfg.should_not be_blank
    one_cfg.should eq @one.appearance.merge({ 'l' => 1, 'id' => @one.id.to_s, 'v' => 0, 'to*' => 'ffff55', 'fg*' => 'ffff55' })
  end

  it 'should send logged in players a message that i have arrived' do
    @one, @o_sock = auth_context(@zone)
    @two, @t_sock, @t_messages = auth_context(@zone)
    @dude, @d_sock = auth_context(@zone)
    @one.send(:update_tracked_entities)
    @two.send(:update_tracked_entities)

    messages = Message.receive_many(@o_sock, max: 3, only: :entity_status)
    messages.map{|m| m[:name]}.flatten.should eq [@two.name, @dude.name]
    messages.map{|m| m[:status]}.flatten.should eq [1, 1]

    messages = Message.receive_many(@t_sock, max: 2, only: :entity_status)
    messages.map{|m| m[:name]}.flatten.should eq [ @dude.name]
    messages.map{|m| m[:status]}.flatten.should eq [1]
  end

  it 'should send logged in players a message that i done left' do
    @one, @o_sock = auth_context(@zone)
    @dude, @d_sock = auth_context(@zone)
    @one.send(:update_tracked_entities)
    @d_sock.close

    messages = Message.receive_many(@o_sock, max: 2, only: :entity_status)
    message = messages[1]

    message[:name].should eq [@dude.name]
    message[:status].should eq [0]
  end

  context 'with a tutorial zone' do
    before(:each) do
      with_a_zone(static: true, static_type: 'tutorial')
    end

    it 'should not send me existing players' do
      @one, @o_sock, @o_messages = auth_context(@zone)
      @two, @t_sock, @t_messages = auth_context(@zone)
      @dude, @d_sock, @d_messages = auth_context(@zone)

      @d_messages.should be_empty
    end
  end
end
