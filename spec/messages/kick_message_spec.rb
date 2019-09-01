require 'spec_helper'

describe 'Kick' do
  before(:each) do
    @socket = connect
  end

  it 'should send a kick for an un-authenticated move command' do
    request = Message.new(:move, [5, 5, 20, 20, 0, 0, 0, 0])
    request.send(@socket)
    
    messages = Message.receive_many(@socket)
    messages.collect(&:ident).should =~ [255]
  end
end