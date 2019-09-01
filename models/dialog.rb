class Dialog

  attr_reader :player, :config, :metadata, :form, :block

  def initialize(player, config, metadata = nil, block = nil)
    @player = player
    @config = config
    @metadata = metadata
    @block = block
  end

  def process_response(values)
    if is_cancellation = values == 'cancel' || (values.is_a?(Array) && values.size == 1 && values.first == 'cancel')
      # Don't process form if cancellation
    else
      @form = Form.new(self, @config, values)
      @form.validate
      values = @form.values # Form converts unity values
      p "[Dialog] Form errors: #{@form.errors}" if Deepworld::Env.development? && @form.errors.present?

      return if @form.errors.present?
    end

    if @block && (!is_cancellation || (metadata && metadata[:cancellation]))
      @block.call values, @form.hashed_values
    end

    if @metadata
      # Use dialog delegate if present
      if delegate = @metadata[:delegate]
        if is_cancellation && delegate.respond_to?(:handle_dialog_cancel)
          delegate.handle_dialog_cancel
        else
          # Custom handler
          if handler = @metadata[:delegate_handle]
            delegate.send handler, player, values
          # Default method
          else
            delegate.handle_dialog values
          end
        end

      # Otherwise, handle based on type (TODO: Move all these into delegates!)
      else
        case @metadata[:type]
        when :confirmation
          return if is_cancellation
          @metadata[:cmd].confirm!

        when :trade
          if @player.trade
            if is_cancellation
              @player.trade.cancel! @player
            else
              @player.trade.continue(@player, values)
            end
          else
            @player.alert "Sorry, there was an error with the trade."
          end

        when :report
          report_type = is_cancellation ? 'cancel' : values.first
          @player.report! @metadata[:player_id], report_type

        when :gadd
          if is_cancellation
            @metadata[:guild].decline_membership @player
          else
            @metadata[:guild].add_member @player
          end

        when :gleader
          if is_cancellation
            @metadata[:guild].decline_leadership @player
          else
            @metadata[:guild].set_leader @player
          end

        when :butler
          return if is_cancellation
          if butler = @player.servants.find{ |s| s.entity_id == @metadata[:entity_id] }
            butler.interact @player, :direct_mode, values.first
          end

        when :minigame
          return if is_cancellation
          Items::Minigame.new(@player, @metadata).use(options: values)

        when :callback
          return if is_cancellation
          @metadata[:object].send(:callback, values)

        end
      end
    end
  end

  def self.values_hash(config, values, player)
    hash = {}

    config.sections.each_with_index do |section, idx|
      if key = section.input['key']
        text = values[idx]
        if section.input['sanitize']
          player.track_obscenity! if Deepworld::Obscenity.is_obscene?(text)
          text = Deepworld::Obscenity.sanitize(text)
          text.gsub! /[^\s]/, '.' if player.muted
        end
        hash[key] = text
      end
    end

    hash
  end

  def self.colored_text(text, color, player)
    if player.v3?
      { text: "<color=##{color}>#{text}</color>" }
    else
      { text: text, 'text-color' => "#{color}" }
    end
  end

end
