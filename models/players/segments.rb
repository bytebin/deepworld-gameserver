module Players
  module Segments

    def segment!(key, val)
      @segments[key] = val.is_a?(Array) ? val.random : val
      update "segments.#{key}" => @segments[key]
    end

    def segment(key)
      @segments[key]
    end

  end
end