module Behavior
  class Dialoguer < Rubyhave::Behavior

    CHOICE_COLOR = '40c0ff'

    def on_initialize
      @last_dialogued_at = Time.now - 1.day
    end

    def behave
      if Ecosystem.time < @last_dialogued_at + 10.seconds
        entity.animation = 0
        Rubyhave::SUCCESS
      else
        Rubyhave::FAILURE
      end
    end

    def can_behave?
      true
    end

    # Recat

    def react(message, params)
      @last_dialogued_at = Ecosystem.time

      case message
      when :interact
        player = params.first
        info = params.last
        job = entity.character.try(:job)

        # Special use cases (dragged inventory, etc.)
        if info.size == 2
          case info[0]
          when 'item'
            item_id = info[1]
            if item = Game.item(item_id)
              if memory = item.use.try(:memory)
                if job.blank?
                  if player.zone.block_protected?(entity.position.fixed, player)
                    say player, Game.config.dialogs.android.protected
                  else
                    player.show_dialog Game.config.dialogs.android.load_memory[memory], true do |resp|
                      player.inv.remove item_id, 1, true
                      entity.name = resp[0]
                      entity.character.update name: entity.name, job: "quester" do
                        player.alert "Android has been reconfigured as #{entity.name}!"
                        entity.change "n" => entity.name
                      end
                    end
                  end
                else
                  say player, Game.config.dialogs.android.cannot_load_memory.random
                end

              elsif item.craft && item.craft.crafter == 'android' && job?('crafter')
                Items::Crafter.new(player, item: item).use!(character_name: entity.name)
              else
                say player, Game.config.dialogs.android.cannot_craft
              end
            end
          end

        elsif job == 'quester'
          offer_quest player

        elsif job == 'interactor'
          player.event! :interact, entity.character

        # Simple interaction - show initial dialog
        else
          player.show_dialog initial_dialog(player), true, { delegate: self, delegate_handle: :handle_initial_dialog }
        end
      end
    end

    def initial_dialog(player)
      character_id = entity.character.try(:id)
      player_daily_ref = player.daily_bonus ? player.daily_bonus['ref'] : nil
      is_daily_interaction = character_id && player_daily_ref && character_id.to_s == player_daily_ref

      { 'type' => 'android',
        'sections' => [
          { 'title' => "#{entity.name} says:" },
          { 'text' => Game.fake(:salutation, is_daily_interaction ? 1 : 0) },
          job?('crafter') ? { 'text' => Game.config.dialogs.android.craft, 'choice' => 'craft', 'text-color' => CHOICE_COLOR } : nil,
          job?('giver') ? { 'text' => is_daily_interaction ? Game.config.dialogs.daily_bonus.subsequent : Game.config.dialogs.daily_bonus.initial, 'choice' => 'daily_bonus', 'text-color' => CHOICE_COLOR } : nil,
          job?('joker') ? { 'text' => Game.config.dialogs.android.joke, 'choice' => 'joke', 'text-color' => CHOICE_COLOR } : nil,
          player.admin? ? { 'text' => 'Can I configure you?', 'choice' => 'configure', 'text-color' => CHOICE_COLOR } : nil,
          player.v3? ? nil : { 'text' => ' ' }
        ].compact
      }
    end

    def job?(type)
      true # Change to == character.job once AMU updates are out
    end

    def handle_initial_dialog(player, values)
      return if values == 'cancel'

      case values.first
      when 'daily_bonus'
        character_id = entity.character.id.to_s
        Items::DailyBonus.new(player).use!(ref: character_id, character_name: entity.name)
      when 'craft'
        say player, Game.config.dialogs.android.craft_response
      when 'joke'
        say player, Game.fake(:jokes)
        entity.emote Game.fake(:laughter) if rand < 0.333
      when 'quest'
        offer_quest player
      when 'configure'
        if player.admin?
          player.show_dialog Game.config.dialogs.android.configure, true do |resp|
            entity.name = resp[0]
            entity.character.update name: resp[0], job: resp[1] do
              player.alert "Cool, I'm now #{resp[0]} the #{resp[1]}!"
            end
          end
        end
      end
    end

    def offer_quest(player)
      if name = entity.character.try(:name)
        if quest_group = Game.config.quests.sources[name.split(' ').first]
          max_level = case name
          when / III$/ then 3
          when / II$/ then 2
          else 1
          end

          player.offer_quest quest_group, name, max_level
          return
        end
      end

      say player, Game.config.dialogs.android.no_quest
    end

    def say(player, msg)
      dialog = {
        'type' => 'android',
        'sections' => [{ 'title' => entity.name }, { 'text' => msg }]
      }
      player.show_dialog dialog, false
    end

  end
end
