require 'spec_helper'

describe Items::Crafter do

  before(:each) do
    with_a_zone
    with_a_player @zone

    @ingredient = stub_item('ingredient')
    @craftable = stub_item('craftable')
  end

  def use!(craft_item = nil)
    Items::Crafter.new(@one, item: @crafter).use!
    dialog = receive_msg!(@one, :dialog).data
    if craft_item
      command! @one, :dialog, [dialog.first, [craft_item]]
    end
    dialog
  end

  it 'should send a sorry message if no crafting options are available' do
    @crafter = stub_item('non-crafter')
    use!.to_s.should =~ /sorry/i
  end

  describe 'valid craftables' do

    before(:each) do
      @crafter = stub_item('crafter', { 'craft' => { 'options' => { 'craftable' => { 'ingredient' => 5 }}}})
    end

    it 'should send crafting options' do
      use!.to_s.should =~ /Craftable/
    end

    it 'should allow a player to craft an item if they have the resources' do
      @one.inv.add @crafter.code, 1
      @one.inv.add @ingredient.code, 5
      use!('craftable')
      receive_msg!(@one, :notification).data.to_s.should =~ /here you go/i
    end

    it 'should add and remove corresponding inventory after crafting' do
      @one.inv.add @crafter.code, 1
      @one.inv.add @ingredient.code, 10
      use!('craftable')

      @one.inv.quantity(@crafter.code).should eq 0
      @one.inv.quantity(@ingredient.code).should eq 5
      @one.inv.quantity(@craftable.code).should eq 1
    end

    it 'should not allow a player to craft if they do not have resources' do
      @one.inv.add @crafter.code, 1
      @one.inv.add @ingredient.code, 3
      use!('craftable')
      receive_msg!(@one, :dialog).data.to_s.should =~ /oops/i

      @one.inv.quantity(@crafter.code).should eq 1
      @one.inv.quantity(@ingredient.code).should eq 3
      @one.inv.quantity(@craftable.code).should eq 0
    end

    it 'should not allow a player to craft if they do not have the source item' do
      @one.inv.add @ingredient.code, 5
      use!('craftable')
      receive_msg!(@one, :dialog).data.to_s.should =~ /oops/i

      @one.inv.quantity(@crafter.code).should eq 0
      @one.inv.quantity(@ingredient.code).should eq 5
      @one.inv.quantity(@craftable.code).should eq 0
    end
  end
end