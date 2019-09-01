module Items
  class Base
    extend Forwardable

    attr_reader :player, :entity, :zone, :params, :command, :position, :item, :meta
    def_delegators :@player, :notify, :alert

    def initialize(player, params = {}, command = nil)
      @entity = params[:entity] || player
      @player = player || (params[:entity].is_a?(Player) ? params[:entity] : nil)

      @zone = params[:zone] || @player.try(:zone) || @entity.try(:zone)
      @params = params
      @command = command
      @position = params[:position]
      @item = params[:item]
      @meta = params[:meta]
    end

    def use!(params = {})
      if validate(params)
        use(params)
      end
    end

    def use(params = {})
      # Override
    end

    def use_and_callback!(params = {})
      used = use!(params)
      if used
        callback
      else
        false
      end
    end

    def destroy!
    end

    def get_meta_block
      @zone.get_meta_block(@position.x, @position.y)
    end



    # ===== Validations ===== #

    def validate(params = {})
      true
    end

    def require_interval(interval, effect = true)
      # Ensure recharge interval has passed between uses
      if @meta['uat'] && Time.now.to_i < @meta['uat'] + interval
        effect! 'steam', 10 if effect
        return false
      end
      @meta['uat'] = Time.now.to_i
      true
    end

    def require_mod(mod)
      @zone.peek(@position.x, @position.y, FRONT)[1] == mod
    end


    # ===== Effects ===== #

    def effect!(name, quantity)
      @zone.queue_message EffectMessage.new((@position.x + 0.5) * Entity::POS_MULTIPLIER, (@position.y + 0.5) * Entity::POS_MULTIPLIER, name, quantity)
    end

    def message!(msg)
      if msg.present?
        fxx = (@position.x + (@meta.item.block_size[0]*0.5)) * Entity::POS_MULTIPLIER
        fxy = (@position.y - @meta.item.block_size[1] + 1) * Entity::POS_MULTIPLIER
        msg = Items::DynamicMessage.new(@meta).interpolate(msg, @entity)
        @zone.queue_message EffectMessage.new(fxx, fxy, 'emote', msg), @zone.chunk_index(@position.x, @position.y)
      end
    end


  end
end