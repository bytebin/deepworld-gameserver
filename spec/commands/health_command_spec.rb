require 'spec_helper'
include EntityHelpers

describe HealthCommand do
  before(:each) do
    @zone = ZoneFoundry.create

    @one, @o_sock = auth_context(@zone)
  end

  it 'should update my health' do
    Message.new(:health, [4000, 0]).send(@o_sock)

    reactor_wait
    @one.health.should eq 4.0
  end

  it 'should not allow my to increase my health' do
    Message.new(:health, [6000, 0]).send(@o_sock)

    reactor_wait
    @one.health.should eq 5.0
  end

  it 'should notify other players of my death and who killed me' do
    @two, @t_sock = auth_context(@zone)
    Message.new(:health, [0, @two.entity_id]).send(@o_sock)

    msg = Message.receive_one(@t_sock, only: :entity_status)
    msg[:status].should eq [2]
    msg[:details].should == [{ '<' => @two.entity_id }]
  end

  it 'should allow a damage type code to be specified' do
    entity = add_entity(@zone, 'terrapus/adult')
    cmd = command!(@one, :health, [0, entity.entity_id, 1])
    cmd.damage_type_code.should eq 1
    cmd.errors.should eq []
  end
end