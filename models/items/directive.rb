module Items
  class Directive < Base

    def use(params = {})
      @player.inv.remove Game.item_code('accessories/program'), 1, true
      @player.directives << directive
      @player.show_dialog [{ 'title' => "#{directive.capitalize} directive installed!" }]

      effect!
    end

    def validate(params = {})
      @player.alert "Error: machine inoperable." and return false unless directive

      if @player.directives.include?(directive)
        @player.alert "You are already equipped with the #{directive} directive."
        return false
      end

      # Require inventory
      unless @player.inv.contains?(Game.item_code('accessories/program'))
        @player.alert "This machine requires an empty directive unit to operate."
        return false
      end

      true
    end

    def directive
      d = @params[:directive].to_i
      Behavior::Butler.directives[d]
    end

    def effect!
      pos = @params[:position] + Vector2[1.0, 1.0]
      @player.zone.queue_message EffectMessage.new(pos.x * Entity::POS_MULTIPLIER, pos.y * Entity::POS_MULTIPLIER, 'bomb-electric', 3)
    end

  end
end