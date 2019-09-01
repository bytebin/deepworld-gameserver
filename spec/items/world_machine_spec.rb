require 'spec_helper'

describe Items::WorldMachines do

  before(:each) do
    with_a_zone
    with_2_players @zone

    @item = stub_item('teleport', meta: 'global', use: { world_machine: 'teleport' })
    @zone.owners << @one.id
    @zone.update_block nil, 10, 10, FRONT, @item.code, 0, @one

    Game.config.stub(:dialogs).and_return(Hashie::Mash.new(YAML.load(
      %[
        world_machines:
          teleport:
            menu:
              sections:
                - title: Configure machine
                  choice: configure
                - title: Destroy natural teleporters
                  choice: deactivate_natural_teleporters
                  power: 2
                - title: Dismantle machine
                  choice: dismantle

            configure:
              sections:
                - title: Teleport to another player (/tp player)
                  input:
                    type: text index
                    options: ['Owners', 'Members', 'Everyone']
                    key: tp
                - title: Summon another player  (/su player)
                  text: Owners can also /su all
                  input:
                    type: text index
                    options: ['Owners', 'Members', 'Everyone']
                    key: su
                - title: Force summon another player  (/suf player)
                  text: Owners can also /suf all
                  input:
                    type: text index
                    options: ['Owners', 'Members', 'Everyone']
                    key: su
                  power: 3
      ]
    )))
  end

  def use!(player = @one)
    Items::WorldMachines::Teleport.new(
      player,
      position: Vector2[10, 10],
      item: @item,
      meta: @zone.get_meta_block(10, 10)
    ).use!
  end

  describe 'permissions' do

    it 'should let an owner interact with a world machine' do
      use!
      receive_msg! @one, :dialog
    end

    it 'should let an owner interact with a world machine even if they did not place it' do
      @zone.owners << @two.id
      use! @two
      receive_msg! @two, :dialog
    end

    it 'should not let a non-owner interact with a world machine' do
      use! @two
      receive_msg!(@two, :notification).data[0].should =~ /owner/
    end

  end

  describe 'configuring' do

    def configure!
      use!
      dialog = receive_msg!(@one, :dialog)
      command! @one, :dialog, [dialog.data[0], ['configure']]
    end

    it 'should let an owner configure a world machine' do
      configure!

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /Teleport to another player/
      dialog.data.to_s.should =~ /Summon another player/

      command! @one, :dialog, [dialog.data[0], [0, 1]]
      eventually do
        @zone.machines_configured.should eq({ 'teleport' => { 'tp' => 0, 'su' => 1, 'position' => [10, 10] }})
      end
    end

    it 'should not show an owner configuration options beyond a machine\'s power' do
      configure!

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should_not =~ /Force summon/
    end

    it 'should show an owner configuration option if adequate power' do
      @item.stub(:power).and_return(3)
      configure!

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /Force summon/
    end

    it 'should show configuration dialog with existing values' do
      @zone.machines_configured['teleport'] = { 'tp' => 1 }
      configure!

      dialog = receive_msg!(@one, :dialog)
      dialog.data[1]['sections'][0]['value'].should eq 1
    end

    pending 'should let an owner dismantle a world machine' do

    end

  end


end