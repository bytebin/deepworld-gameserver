class Form

  attr_accessor :values, :hashed_values, :errors
  attr_reader :input_sections

  def initialize(player, config, values = nil)
    @player = player
    @config = Hashie::Mash.new(config)
    @values = values
    @errors = []
  end

  def validate
    unless @values
      @errors << "No arguments"
      return
    end

    # ===== "Choice" input ===== #
    if @config.sections.any?{ |s| s['choice'] }

      if @values.size != 1
        @errors << "Improper number of arguments"
      else
        @values = [@values["choice"]] if @values.is_a?(Hash) # v3 support
        @errors << "Invalid choice" unless @config.sections.any?{ |s| s['choice'] == @values.first }
      end

    # ===== "Actions" input ===== #
    elsif @config.actions.is_a?(Array)
      @values = @values.values if @values.is_a?(Hash)

      if @values.size != 1
        @errors << "Improper number of arguments"
      else
        @errors << "Invalid action" unless @config.actions.include?(@values.first)
      end

    # ===== Standard input ===== #

    else
      @hashed_values = {}
      @input_sections = @config.sections.select{ |s| s['input'].present? }

      # Convert hash to array for now (Unity)
      if @values.is_a?(Hash)
        h = @values
        @values = @input_sections.map do |section|
          section.input.mod ? h['mod'] : h[section.input['key']]
        end
      end

      # Form arguments must have same amount of items as config
      if @values.size != @input_sections.size
        @errors << "Improper number of arguments"

      else
        @input_sections.each_with_index do |section, idx|
          value = @values[idx]
          friendly_name = section.input['key'] ? section.input['key'].titleize : value
          @hashed_values[section.input['key']] = value

          case section.input.type
          when 'text'
            @errors << "#{friendly_name} should be text" unless value.is_a?(String)
            unless ((section.input['min'] || 0)..(section.input['max'] || 9999)).include?(value.to_s.size)
              @errors << "#{friendly_name} must be within min #{section.input.min || 0} or max #{section.input.max || 9999}"
            end
            if conversion = section.input.conversion
              if conversion.type == "number"
                if value.present? || !conversion.allow_blank
                  valueNum = value.to_i
                  @errors << "#{friendly_name} must be a number" unless value.strip =~ /^\d+$/
                  @errors << "#{friendly_name} must be at least #{conversion['min']}" if conversion['min'] && valueNum < conversion['min']
                  @errors << "#{friendly_name} must be at most #{conversion['max']}" if conversion['max'] && valueNum > conversion['max']
                end
              end
            end
          when 'item'
            item = Game.item(value)
            if item
              @errors << "Value #{item.category}/#{item.name} must match category #{section.input.category}" if (section.input.category.present? and item.category != section.input.category)

              # Appearance items must be "base: true" or in player's wardrobe
              if @config.target == 'appearance'
                @errors << "Item #{item.name} must be base or in player's wardrobe" unless (item.base or @player.wardrobe.include?(item.code))
              end
            else
              @errors << "Value #{value} is not a valid item exist"
            end
          when 'select', 'text select', 'color'
            options = (referenced_options(section.input.options) rescue [])
            @errors << "Value #{value} must be in options" unless options.include?(value)
          when 'text index'
            options = (referenced_options(section.input.options) rescue [])
            @errors << "Value #{value} must be in range" unless (0..options.size-1).include?(value)
          end
        end

      end
    end
  end

  def referenced_options(options)
    original_options = options

    if options.is_a?(Array)
      # Pull 'value' out of options array if extant
      if options.first.is_a?(Hash)
        options.map{ |o| o['value'] }

      # Otherwise use options as-is
      else
        options
      end

    # If options is an @ reference, get it from config hash
    elsif options.is_a?(String) && options[0] == '@'
      path = options[1..-1].split('.')
      options = Game.config
      path.each do |p|
        options = options[p]
      end

      # TODO: Somehow make this configurable?
      if @player.inv.contains?(Game.item('accessories/makeup').code)
        if %w{skin-color hair-color}.include?(path.last)
          options = options + (referenced_options("#{original_options}-bonus") rescue [])
        end
      end

      options

    else
      raise "Invalid options reference: #{options}"
    end
  end

end
