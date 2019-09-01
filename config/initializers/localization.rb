require "i18n"

I18n.load_path = Dir["#{Deepworld::Loader.root}/config/locales/*.yml"]
I18n.backend.load_translations
I18n.default_locale = :en
