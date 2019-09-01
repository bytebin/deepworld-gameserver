module Players
  class SkillUpgrade

    def initialize(player)
      @player = player

      skills = @player.upgradeable_skills

      if @player.points == 0
        fail Game.config.dialogs.skill_upgrade_no_points

      elsif skills.size == 0
        fail Game.config.dialogs['skill_upgrade_no_skills']

      else
        dialog = Game.config.mutable_dialog('skill_upgrade')
        dialog.sections[0].delete 'text' if @player.level >= 10
        dialog.sections[0].input['options'] = skills.sort.map do |sk|
          player.v3? ? { 'title' => sk.capitalize, 'value' => sk } : sk
        end

        if player.v2?
          dialog.sections[0].input['type'] = 'text select'
          dialog.sections[0].input['max columns'] = 5
        end

        @player.show_dialog dialog, true do |values|
          if @player.points > 0
            sk = values[0]
            if msg = @player.upgrade_skill(sk)
              @player.alert msg
              @player.queue_message StatMessage.new('points', @player.points)
            end
          else
            fail Game.config.dialogs.skill_upgrade_no_points
          end
        end
      end
    end

    def fail(msg)
      @player.show_modal_message msg
    end

  end
end