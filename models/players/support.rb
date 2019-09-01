module Players
  module Support

    def client_version?(version)
      current_client_version && Versionomy.parse(current_client_version) >= Versionomy.parse(version)
    end

    def supports?(feature)
      case feature
      when :lock
        v2? && current_client_version != '2.0.2'
      end
    end

    def v2?
      !v3?
    end

    def v3?
      @is_v3 ||= (current_client_version && current_client_version[0] == '3')
    end

    def windows?
      platform == 'Windows'
    end

    def touch?
      platform && platform =~ /^(iPh|iPo|iPa|iOS)/
    end

    def small_screen?
      (platform && platform =~ /^(iPh|iPo)/) || @small_screen
    end

    def fast_device?
      platform && platform =~ /^(Mac|iPhone 5|iPad 3|iPad 4)/
    end

  end
end