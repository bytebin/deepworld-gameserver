require 'spec_helper'

describe Players::Quests do

  before(:each) do
    with_a_zone
    with_a_player(@zone)

    @baby_terrapus = Hashie::Mash.new(code: 3, config: { code: 3 })
    @terrapus = Hashie::Mash.new(code: 4, config: { code: 4 })

    @time = Time.now
    stub_date @time

    @gimme_item_1 = stub_item('gimme1')
    @gimme_item_2 = stub_item('gimme2')
    @get_item_1 = stub_item('get1')
    @get_item_2 = stub_item('get2')

    Game.config.stub(:quests).and_return(Hashie::Mash.new(YAML.load(
      %[
        messages:
          no_more: "You've reached the end!"
          incomplete: "How's that quest going?"
          too_high_level_begin: "Too high level! Find a $."
          too_high_level_complete: "Too high level! Find a $."
          cannot_collect: "Oops, looks like you don't have all the items I need yet."
          ready_to_collect: "Ready to hand over these items?"
          collect_no: Not yet.
          collect_yes: Yep!

        details:
          hunt_some_terrapi:
            id: hunt_some_terrapi
            title: Hunt Some Terrapi
            group: Combat
            level: 1
            reward:
              xp: 250
            story:
              intro: "I've been looking for someone to help kill off some terrapi, interested?"
              accept: "For sure!"
              cancel: "Nah, too busy."
              begin: "Great. Good luck."
              incomplete: "How is that pest control going?"
              complete: "Tremendous! Thanks for getting rid of those nasties. Here is your reward."
            desc: "Terrapi are a common scourge in Deepworld. They attack humans on sight and deserve no mercy in return."
            tasks:
              - desc: Find and kill 5 terrapi with sledgehammer
                events:
                  - ['kill', 'code', 3]
                  - ['kill', 'code', 4]
                quantity: 5
              - desc: Do 2 things
                events:
                  - ['thing']
                progress:
                  - ['things']
                quantity: 2
          hunt_more_terrapi:
            id: hunt_more_terrapi
            title: Hunt More Terrapi
            group: Combat
            level: 2
            reward:
              xp: 500
            story:
              intro: "I need more terrapi destruction!"
              incapable: "Sorry, I'm not high-enough level to do that!"
            desc: "Terrapi are a common scourge in Deepworld. They attack humans on sight and deserve no mercy in return."
            tasks:
              - desc: Find and kill 25 terrapi
                events:
                  - ['kill', 'code', '3']
                  - ['kill', 'code', '4']
                quantity: 25
          gimme_stuff:
            id: gimme_stuff
            title: Gimme Some Stuff
            group: Collector
            story:
              intro: Gimme some stuff.
              begin: Gimme some stuff.
              accept: "I'll give it!"
              cancel: "No thanks."
            level: 1
            reward:
              xp: 250
              inventory:
                get1: 10
                get2: 20
              crowns: 25
            desc: "I need some stuff, so gimme it."
            tasks:
              - desc: Give the android some stuff
                collect_inventory:
                  gimme1: 5
                  gimme2: 10
          gimme_more_stuff:
            id: gimme_more_stuff
            title: Gimme Some More Stuff
            group: Collector
            story:
              intro: Gimme some stuff.
              begin: Gimme some stuff.
              accept: "I'll give it!"
              cancel: "No thanks."
              incomplete: "Can't gimme yet"
            level: 1
            reward:
              xp: 250
            desc: "I need some stuff, so gimme it."
            tasks:
              - desc: Do something else first
                events:
                  - ['gimme']
              - desc: Give the android some stuff
                collect_inventory:
                  gimme1: 5
                  gimme2: 10
          qualify_for_it:
            id: qualify_for_it
            title: Qualify For It
            group: Qualifier
            level: 1
            reward:
              xp: 250
            desc: "Let's see if you can do this."
            story:
              intro: Do it up.
            tasks:
              - desc: Do some events
                events:
                  - ['boom']
                quantity: 3
                qualify:
                  - ['is_good?']
                  - ['has_item?', 3]
          return_to_source:
            id: return_to_source
            title: Return to source!
            group: Return
            level: 2
            reward:
              xp: 250
            desc: "Come back after you do the thing"
            story:
              intro: Come back and stuff.
            tasks:
              - desc: Do a thing
                events:
                  - ['thing']
              - desc: Return to the android
                events:
                  - ['return']
          return_to_source_harder:
            id: return_to_source_harder
            title: Return to source harder!
            group: Return
            level: 3
            story:
              intro: Come back again yo
            reward:
              xp: 500
            desc: Yet more returning
            tasks:
              - desc: Do a thing
                events:
                  - ['thing']
              - desc: Return to the android
                events:
                  - ['return']
          get_stuff_at_beginning:
            id: get_stuff_at_beginning
            title: Get Stuff
            group: Get Stuff at Beginning
            story:
              intro: "You're gonna need stuff!"
              begin: "Here is some stuff!"
            reward:
              xp: 100
            actions:
              begin:
                - actor: player
                  method: gift_items!
                  params:
                    - get1: 10
                      get2: 5
            desc: "Get stuff"
            tasks:
              - desc: Find and kill 25 terrapi
                events:
                  - ['kill', 'code', '3']
                quantity: 25
            zones:
              - zone1
              - zone2
      ]
    )))
  end

  describe 'offering' do

    it 'should offer the lowest-level quest a player has not begun' do
      @one.offer_quest 'Combat', 'Dude'

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /kill off some terrapi/
      dialog.data[1]['actions'].should eq ['Nah, too busy.', 'For sure!']
    end

    it 'should offer high-level quests if capable' do
      @one.quests['hunt_some_terrapi'] = { 'completed_at' => @time.to_i }
      @one.offer_quest 'Combat', 'Dude'

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /more terrapi destruction/
    end

    it 'should not offer high-level quests if incapable' do
      @one.quests['hunt_some_terrapi'] = { 'completed_at' => @time.to_i }
      @one.offer_quest 'Combat', 'Dude', 1

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /find a dude II/i
    end

    it 'should offer no quests if all complete in a group' do
      @one.quests['hunt_some_terrapi'] = { 'completed_at' => @time.to_i }
      @one.quests['hunt_more_terrapi'] = { 'completed_at' => @time.to_i }
      @one.offer_quest 'Combat', 'Dude'

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /reached the end/
    end

    it 'should begin the quest if player agrees' do
      @one.offer_quest 'Combat', 'Dude'
      dialog = receive_msg!(@one, :dialog)
      command! @one, :dialog, [dialog.data.first, ['For sure!']]

      @one.quests['hunt_some_terrapi'].should be_present
      @one.quests['hunt_some_terrapi']['began_at'].should eq @time.to_i
    end

    it 'should note that the quest is already assigned if the player returns incomplete' do
      @one.quests['hunt_some_terrapi'] = { 'began_at' => @time.to_i, 'tasks' => {} }
      @one.offer_quest 'Combat', 'Dude'

      dialog = receive_msg!(@one, :dialog)
      dialog.data.to_s.should =~ /how is that pest control/i
    end

  end

  describe 'beginning' do

    it 'should send quest info once assigned to a player' do
      @one.begin_quest 'hunt_some_terrapi'
      msg = receive_msg!(@one, :quest)
      msg.data.should eq([[{
        'id' => 'hunt_some_terrapi',
        'title' => 'Hunt Some Terrapi',
        'group' => 'Combat',
        'xp' => 250,
        'reward' => { 'xp' => 250 },
        'desc' => 'Terrapi are a common scourge in Deepworld. They attack humans on sight and deserve no mercy in return.',
        'tasks' => ['Find and kill 5 terrapi with sledgehammer', 'Do 2 things']
      }, {
        'progress' => [],
        'complete' => false,
        'active' => false
      }]])
    end

    it 'should perform begin events' do
      @one.begin_quest 'get_stuff_at_beginning'
      @one.inventory[@get_item_1.code.to_s].should eq 10
      @one.inventory[@get_item_2.code.to_s].should eq 5
    end

    it 'should add zones to quest status' do
      @one.begin_quest 'get_stuff_at_beginning'
      @one.quests['get_stuff_at_beginning']['zones'].should eq ['zone1', 'zone2']
    end

  end

  describe 'tasks' do

    it 'should complete a task based on a progress method' do
      @one.begin_quest 'hunt_some_terrapi'
      @one.stub(:things).and_return(5)
      @one.event! :thing, nil
      receive_msg!(@one, :notification)

      @one.quest_status('hunt_some_terrapi')['tasks'].should eq({ '1' => true })

      msg = receive_msg!(@one, :notification)
      msg.data.to_s.should =~ /task completed/i

      msg = receive_msg!(@one, :quest)
      msg.data.first[1].should eq({
        'active' => false,
        'complete' => false,
        'progress' => [1]
      })

      @one.quests['completed_at'].should be_nil
    end

    it 'should complete a task based on tracked progress' do
      @one.begin_quest 'hunt_some_terrapi'
      5.times { @one.event! :kill, @terrapus }
      receive_msg!(@one, :notification)

      @one.quest_status('hunt_some_terrapi')['tasks'].should eq({ '0' => true })

      msg = receive_msg!(@one, :notification)
      msg.data.to_s.should =~ /task completed/i

      msg = receive_msg!(@one, :quest)
      msg.data.first[1].should eq({
        'progress' => [0],
        'active' => false,
        'complete' => false
      })

      @one.quests['completed_at'].should be_nil
    end

    it 'should complete a task if qualified' do
      @one.begin_quest 'qualify_for_it'
      @one.stub(:is_good?).and_return(true)
      @one.stub(:has_item?).and_return(true)
      3.times { @one.event! :boom, nil }

      @one.quest_complete?('qualify_for_it').should be_true
    end

    it 'should not complete a task if unqualified' do
      @one.begin_quest 'qualify_for_it'
      @one.stub(:is_good?).and_return(true)
      @one.stub(:has_item?).and_return(false)
      3.times { @one.event! :boom, nil }

      @one.quest_complete?('qualify_for_it').should_not be_true
    end

    it 'should not complete a task twice' do
      @one.begin_quest 'hunt_some_terrapi'
      receive_msg!(@one, :notification)
      5.times { @one.track_kill @terrapus }
      msg = receive_msg!(@one, :notification)

      5.times { @one.track_kill @terrapus }
      receive_msg(@one, :notification).should be_nil
    end

    it 'should not reward twice even if completed_at gets messed up' do
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'
      @one.quests.delete 'hunt_some_terrapi'
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'
      @one.xp.should eq 250
    end

    describe 'collecting' do

      it 'should not collect inventory if there are other tasks remaining first' do
        @one.quests['gimme_stuff'] = { 'completed_at' => Time.now.to_i }
        @one.begin_quest 'gimme_more_stuff'
        dialog = receive_msg(@one, :dialog)

        @one.offer_quest 'Collector', 'Dude'
        receive_msg!(@one, :dialog).data.to_s.should =~ /can't gimme yet/i
      end

      it 'should complete task by collecting inventory' do
        @one.inv.add @gimme_item_1.code, 10
        @one.inv.add @gimme_item_2.code, 10
        @one.begin_quest 'gimme_stuff'
        @one.offer_quest 'Collector', 'Dude'

        dialog = receive_msg(@one, :dialog)
        dialog.data[1].to_s.should =~ /gimme1 x 5/i
        dialog.data[1].to_s.should =~ /gimme2 x 10/i
        command! @one, :dialog, [dialog.data[0], ['Yep!']]

        @one.inv.quantity(@gimme_item_1.code).should eq 5
        @one.inv.quantity(@gimme_item_2.code).should eq 0
      end

      it 'should alert player they do not have inventory' do
        @one.begin_quest 'gimme_stuff'
        @one.offer_quest 'Collector', 'Dude'

        dialog = receive_msg(@one, :dialog)
        dialog.data[1].to_s.should =~ /how's that quest going?/i
      end

      it 'should ask to complete task by collecting inventory right after beginning quest if player has inventory (if that is the only task)' do
        @one.inv.add @gimme_item_1.code, 10
        @one.inv.add @gimme_item_2.code, 10
        @one.offer_quest 'Collector', 'Dude'
        dialog_id = receive_msg!(@one, :dialog).data[0]
        command! @one, :dialog, [dialog_id, ["I'll give it!"]]

        dialog = receive_msg!(@one, :dialog)
        command! @one, :dialog, [dialog.data[0], ['Okay']]

        dialog = receive_msg!(@one, :dialog)
        dialog.data[1].to_s.should =~ /gimme1 x 5/i
        dialog.data[1].to_s.should =~ /gimme2 x 10/i

        command! @one, :dialog, [dialog.data[0], ['Yep!']]

        @one.inv.quantity(@gimme_item_1.code).should eq 5
        @one.inv.quantity(@gimme_item_2.code).should eq 0
      end

      it 'should not ask to complete task by collecting inventory right after beginning quest if player has inventory (if not the only task)' do
        @one.quests['gimme_stuff'] = { 'completed_at' => Time.now.to_i }
        @one.inv.add @gimme_item_1.code, 10
        @one.inv.add @gimme_item_2.code, 10
        @one.offer_quest 'Collector', 'Dude'
        dialog_id = receive_msg!(@one, :dialog).data[0]
        command! @one, :dialog, [dialog_id, ["I'll give it!"]]

        dialog = receive_msg!(@one, :dialog)
        command! @one, :dialog, [dialog.data[0], ['Okay']]

        receive_msg(@one, :dialog).should be_blank
      end

    end

  end

  describe 'quest completion' do

    it 'should complete a quest when tasks are finished' do
      @one.begin_quest 'hunt_some_terrapi'
      3.times { @one.track_kill @terrapus }
      2.times { @one.track_kill @baby_terrapus }

      @one.quest_status('hunt_some_terrapi')['completed_at'].should be_blank

      @one.stub(:things).and_return(20)
      @one.event! :thing, nil

      @one.quest_status('hunt_some_terrapi')['completed_at'].should eq @time.to_i
    end

    it 'should not complete a quest twice' do
      @one.mobs_killed = { @terrapus.code.to_s => 1 }
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'

      3.times { @one.track_kill @terrapus }
      @one.complete_quest 'hunt_some_terrapi'

      @one.xp.should eq 250
    end

    it 'should complete a quest when tasks are finished and player returns to source' do
      @one.begin_quest 'return_to_source'
      @one.quest_status('return_to_source')['tasks']['0'] = true
      @one.offer_quest 'Return', 'RoboGuy'

      @one.quest_status('return_to_source')['completed_at'].should eq @time.to_i
    end

    it 'should not complete a quest if returning to a different source' do
      @one.begin_quest 'return_to_source'
      @one.quest_status('return_to_source')['tasks']['0'] = true
      @one.offer_quest 'NoReturn', 'RoboGuy'

      @one.quest_status('return_to_source')['completed_at'].should be_nil
    end

    it 'should not complete a quest if returning to an incapable source' do
      @one.begin_quest 'return_to_source'
      @one.quest_status('return_to_source')['tasks']['0'] = true
      @one.offer_quest 'Return', 'RoboGuy', 1

      @one.quest_status('return_to_source')['completed_at'].should be_nil
    end

    it 'should show an android dialog if completing at source' do
      @one.begin_quest 'return_to_source'
      @one.quest_status('return_to_source')['tasks']['0'] = true
      @one.offer_quest 'Return', 'RoboGuy'

      receive_msg!(@one, :dialog).data[1]['type'].should eq 'android'
    end

    it 'should show a normal dialog if not completing at source' do
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'

      receive_msg!(@one, :dialog).data[1]['type'].should be_nil
    end

    pending 'should offer the next level quest after completion if completing at source' do
      @one.begin_quest 'return_to_source'
      @one.quest_status('return_to_source')['tasks']['0'] = true
      @one.offer_quest 'Return', 'RoboGuy'
      dialog_id = receive_msg!(@one, :dialog).data[0]
      command! @one, :dialog, [dialog_id, ['Okay']]

      next_quest_dialog = receive_msg!(@one, :dialog)
      next_quest_dialog.data.to_s.should =~ /come back again yo/i
    end

    it 'should not offer the next level quest after completion if not completing at source' do
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'
      dialog_id = receive_msg!(@one, :dialog).data[0]
      command! @one, :dialog, [dialog_id, ['Okay']]

      receive_msg(@one, :dialog).should be_blank
    end

    it 'should reward XP' do
      @one.begin_quest 'hunt_some_terrapi'
      @one.complete_quest 'hunt_some_terrapi'
      @one.xp.should eq 250
    end

    it 'should reward inventory' do
      @one.begin_quest 'gimme_stuff'
      @one.complete_quest 'gimme_stuff'
      @one.inventory[@get_item_1.code.to_s].should eq 10
      @one.inventory[@get_item_2.code.to_s].should eq 20
      receive_msg! @one, :inventory
    end

    it 'should reward crowns' do
      @one.begin_quest 'gimme_stuff'
      @one.complete_quest 'gimme_stuff'
      @one.crowns.should eq 25
    end

  end

  describe 'stats' do

    before(:each) do
      %w{hunt_some_terrapi hunt_more_terrapi gimme_stuff}.each do |q|
        @one.begin_quest q
        @one.complete_quest q
      end
    end

    it 'should return quests complete' do
      @one.quests_completed.should eq ['hunt_some_terrapi', 'hunt_more_terrapi', 'gimme_stuff']
    end

    it 'should return quests complete in a group' do
      @one.quests_completed_in_group('Combat').should eq ['hunt_some_terrapi', 'hunt_more_terrapi']
    end

  end

end
