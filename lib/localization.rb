class Loc
  def self.t(*args); self.translate(*args); end
  def self.translate(locale, key, args={})
    I18n.t(key, args.merge(locale: locale))
  end
end
