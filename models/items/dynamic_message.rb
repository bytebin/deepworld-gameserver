module Items
  class DynamicMessage

    def initialize(meta)
      @meta = meta
    end

    def interpolate(original_message, entity = nil)
      msg = original_message.dup
      if name = entity.try(:name)
        msg.gsub! /\*(player|mob)\*/, name
      end
      msg.gsub! /\*name\*/, Game.fake(:first_name)
      msg.gsub! /\*n\*/, "\n"

      Deepworld::Obscenity.sanitize(msg)
    end

  end
end