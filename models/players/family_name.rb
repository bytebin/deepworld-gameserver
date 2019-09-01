module Players
  module FamilyName

    def set_family_name!
      unless family_name
        @family_name = Players::FamilyName.random
        update family_name: @family_name
        alert_profile "You've discovered your Family Name!", "Welcome to the House of #{family_name}."
        add_xp 500
      end
    end

    def self.random
      %w{Faraday Wilde Nightingale Kingsley Talbot Livingstone Gaskell Brunel}.random
    end

  end
end