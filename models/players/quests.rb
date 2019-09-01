module Players
  module Quests

    # Offering

    def offer_quest(quest_group, source_name = nil, max_level = nil)
      # If in tutorial and a quest has been completed, send to spawn zone
      if tutorial? && quests_completed.size > 0
        send_to_spawn_zone!
        return
      end

      current_quest = Game.config.quests.details.values.find do |quest|
        quest.group == quest_group && !quest_complete?(quest.id)
      end

      if current_quest
        too_high_level = max_level && max_level < (current_quest.level || 0)

        # In progress
        if quest_in_progress?(current_quest.id)
          # If only task left is to return to source, complete quest
          tasks_remaining = quest_tasks_remaining(current_quest.id)
          if tasks_remaining.size == 1 && tasks_remaining[0].events == [['return']]
            if too_high_level
              msg = Game.config.quests.messages.too_high_level_complete.sub(/\$/, "#{source_name.sub(/\sI+/, '')} #{'I' * current_quest.level}")
              show_android_dialog msg, source_name
            else
              complete_task current_quest.id, tasks_remaining[0], current_quest.tasks.size - 1, source_name
              save_quests!
            end

          # Else if collection task is left, try to collect
          elsif can_collect_for_quest?(current_quest.id)
            collect_for_quest! current_quest.id, source_name

          # Otherwise show "incomplete" message
          else
            show_android_dialog current_quest.try(:story).try(:incomplete) || Game.config.quests.messages.incomplete, source_name
            action_for_quest! current_quest.id, 'incomplete'
          end

        # New quest offer
        else
          # Let player know if quest is too high-level for this android
          if too_high_level
            msg = Game.config.quests.messages.too_high_level_begin.sub(/\$/, "#{source_name.sub(/\sI+/, '')} #{'I' * current_quest.level}")
            show_android_dialog msg, source_name

          # Good to go! Start dat quest.
          else
            actions = [current_quest.story.cancel || Game.config.quests.messages.not_yet, current_quest.story.accept]
            show_android_dialog current_quest.story.intro, source_name, actions do |resp|
              if resp[0] == current_quest.story.accept
                # Begin if they accept!
                begin_quest current_quest.id

                # Show dialog with begin text
                txt = touch? ? current_quest.story.begin_mobile || current_quest.story.begin : current_quest.story.begin
                show_android_dialog txt, source_name do |resp|
                  # If collection quest, see if we're already good to go after they click "ok"
                  if can_collect_for_quest?(current_quest.id)
                    collect_for_quest! current_quest.id, source_name
                  end
                end
              end
            end
          end
        end

      else
        show_android_dialog Game.config.quests.messages.no_more, source_name
      end
    end


    # Beginning

    def begin_quest(quest_id)
      if quest_unstarted?(quest_id)
        quest = quest_details(quest_id)

        @quests[quest_id] = {
          'began_at' => Time.now.to_i,
          'tasks' => {}
        }
        @quests[quest_id]['zones'] = quest.zones if quest.zones

        alert_profile "Quest added!", "- #{quest.title}"
        action_for_quest! quest_id, 'begin'
      end

      send_quest_message quest_id
      save_quests!
    end


    # Status

    def quest_status(quest_id)
      @quests[quest_id]
    end

    def quest_details(quest_id)
      Game.config.quests.details[quest_id]
    end

    def quest_unstarted?(quest_id)
      !quest_status(quest_id)
    end

    def quest_in_progress?(quest_id)
      quest_status(quest_id) && !quest_status(quest_id)['completed_at'].present?
    end

    def quest_complete?(quest_id)
      quest_status(quest_id) && quest_status(quest_id)['completed_at'].present?
    end

    def quest_tasks_remaining(quest_id)
      quest = quest_details(quest_id)
      status = quest_status(quest_id)
      quest.tasks.each_with_index.select{ |t, idx| status['tasks'][idx.to_s] != true }.map(&:first)
    end

    def quest_ends_with_return?(quest_id)
      quest_details(quest_id).tasks.last.events == ['return']
    end

    def quest_collects?(quest_id)
      quest_details(quest_id).tasks.last.collect_inventory.present?
    end

    def can_collect_for_quest?(quest_id)
      quest_collects?(quest_id) &&
        quest_tasks_remaining(quest_id).size == 1 &&
        quest_details(quest_id).tasks.last.collect_inventory.all?{ |item_name, quantity|
          self.inv.quantity(Game.item(item_name).code) >= quantity
        }
    end

    def quests_completed
      @quests.inject([]) do |arr, q|
        arr << q[0] if q[1]['completed_at'].present?
        arr
      end
    end

    def quests_completed_in_group(group)
      @quests.inject([]) do |arr, q|
        quest = quest_details(q[0])
        arr << q[0] if quest['group'] == group && q[1]['completed_at'].present?
        arr
      end
    end

    def save_quests!
      update quests: @quests
      @quests_changed = false
    end




    # Events

    def quest_event(event, event_data)
      event = event.to_s
      @quests.each_pair do |quest_id, status|
        unless status['completed_at']
          if quest = quest_details(quest_id)
            quest.tasks.each_with_index do |task, idx|
              unless status['tasks'][idx.to_s] == true || task.events.blank?
                if task.events.any?{ |e| e.first == event }
                  check_task quest_id, task, idx, event, event_data
                end
              end
            end
          end
        end
      end

      # Update DB if quest status changed
      if @quests_changed
        save_quests!
      end
    end

    def quests_changed!
      @quests_changed = true
    end

    def check_task(quest_id, task, task_idx, event, event_data)
      quest = quest_details(quest_id)

      if task.qualify
        return unless task.qualify.all? do |q|
          q.size == 1 ? send_safe(q[0]) : send_safe(q[0], q[1])
        end
      end

      progress = 0

      # If progress methods, call directly on player object
      if task.progress
        progress = task.progress.inject(0) do |ct, progression|
          ct += (progression.size > 1 ? self.send_safe(progression[0], progression[1]) : self.send_safe(progression[0])) || 0
          ct
        end

      # Otherwise track event in quest status
      elsif task.events.present?
        # If any events match, increment status by one
        if task.events.any?{ |e|
          e[0] == event &&
          (e.size == 1) ||
          (e.size == 2 && event_data == e[1]) ||
          (e.size == 3 && event_data.send_safe(e[1]) == e[2]) }

          status = quest_status(quest.id)
          progress = (status['tasks'][task_idx.to_s] || 0) + 1
          status['tasks'][task_idx.to_s] = progress
          quests_changed!
        end
      end

      if progress >= (task.quantity || 1)
        complete_task quest_id, task, task_idx
      end
    end

    def complete_task(quest_id, task, task_idx, source_name = nil)
      quest = quest_details(quest_id)
      status = quest_status(quest_id)

      action_for_quest! quest_id, task.action if task.action

      unless status && status['tasks'] && status['tasks'][task_idx.to_s] == true
        status['tasks'][task_idx.to_s] = true

        # If tasks are all done, quest is complete
        tasks_complete = status['tasks'].values.count{ |t| t == true }
        if tasks_complete == quest.tasks.size
          complete_quest quest_id, source_name

        # Otherwise, just notify of task completion
        else
          alert_profile "Task completed!", "- #{task.desc}"
        end

        send_quest_message quest_id
        quests_changed!
      end
    end

    def complete_quest(quest_id, source_name = nil)
      quest = quest_details(quest_id)
      status = quest_status(quest_id)

      unless status && status['completed_at']
        status['completed_at'] = Time.now.to_i

        rewards = []
        unless loot?(quest_id)
          # Reward crowns
          rewards << Dialog.colored_text('You earned:', 'e05c19', self)
          if quest.reward.crowns
            Transaction.credit(self, quest.reward.crowns, 'quest')
            rewards << { 'text' => "+ #{quest.reward.crowns} crowns" }
          end

          # Reward XP
          if quest.reward.xp
            add_xp quest.reward.xp
            rewards << { 'text' => "+ #{quest.reward.xp}xp" }
          end

          # Reward inventory
          if quest.reward.inventory
            quest.reward.inventory.each_pair do |item_name, quantity|
              item = Game.item(item_name)
              self.inv.add item.code, quantity, true
              self.track_inventory_change :quest, item.code, quantity
              rewards << { 'text' => "+ #{item.title} x #{quantity}" }
            end
          end

          @loots << quest_id
        end

        # Send dialog
        dialog = {
          'title' => source_name ? "#{source_name} says:" : "Quest complete!",
          'sections' => [{ 'text' => interpolate_dialog_text(quest.story.complete) }] + rewards
        }
        dialog['type'] = 'android' if source_name
        dialog['sections'][0]['title'] = dialog.delete('title') if v2?

        show_dialog dialog, true do |resp|
          if source_name
            max_level = case source_name
            when / III$/ then 3
            when / II$/ then 2
            else 1
            end
            offer_quest quest.group, source_name, max_level
          end
        end

        action_for_quest! quest_id, 'complete'
        event! :complete_quest, quest
      end
    end

    def set_active_quest(quest_id)
      @active_quest = quest_id
    end


    # Actions

    def action_for_quest!(quest_id, action_group)
      quest = quest_details(quest_id)
      if quest.actions
        if actions = quest.actions[action_group]
          actions.each do |action|
            recipient = self
            if action['params']
              recipient.send_safe action['method'], *action['params']
            else
              recipient.send_safe action['method']
            end
          end
        end
      end
    end

    def collect_for_quest!(quest_id, source_name = nil)
      if quest_collects?(quest_id)
        quest = quest_details(quest_id)
        if can_collect_for_quest?(quest_id)
          sections = [{ 'text' => Game.config.quests.messages.ready_to_collect }]
          quest.tasks.last.collect_inventory.each_pair do |item_name, quantity|
            sections << { 'text' => "#{Game.item(item_name).title} x #{quantity}" }
          end
          actions = [Game.config.quests.messages.collect_no, Game.config.quests.messages.collect_yes]
          show_android_dialog sections, source_name, actions do |resp|
            if resp == [Game.config.quests.messages.collect_yes]
              if can_collect_for_quest?(quest_id)
                quest.tasks.last.collect_inventory.each_pair do |item_name, quantity|
                  self.inv.remove Game.item(item_name).code, quantity, true
                end

                complete_task quest_id, quest.tasks.last, quest.tasks.size - 1, source_name
                save_quests!
              end
            end
          end
        else
          show_android_dialog Game.config.quests.messages.cannot_collect, source_name
        end
      end
    end


    # Messages

    def send_quest_message(quest_id)
      if quest = quest_details(quest_id)
        # Cache quest data if not yet cached
        unless quest.client
          quest.client = Marshal.load(Marshal.dump(quest))
          quest.client.xp = quest.client.reward.xp
          quest.client.delete :story
          quest.client.delete :level
          quest.client.tasks = quest.client.tasks.map(&:desc)

          quest.client_mobile = Marshal.load(Marshal.dump(quest.client))
          quest.client_mobile.desc = quest.client_mobile.desc_mobile if quest.client_mobile.desc_mobile
        end

        status = quest_status(quest_id)
        send_status = {
          progress: quest.tasks.each_with_index.map{ |t, idx| status['tasks'][idx.to_s] == true ? idx : nil }.compact,
          complete: status['completed_at'].present?,
          active: @active_quest == quest_id
        }

        queue_message QuestMessage.new(touch? ? quest.client_mobile : quest.client, send_status)
      end
    end

    def send_initial_quest_messages
      keys = client_version?('2.5.0') ? @quests.keys : @quests.keys.reverse
      keys.each do |quest_id|
        send_quest_message quest_id
      end
    end


    # Misc

    def begin_first_quest_if_necessary
      if !@zone.tutorial? && !zone.beginner? && @quests.blank?
        offer_quest "Survive and Thrive", "Newton", 1
      end
    end

  end
end
