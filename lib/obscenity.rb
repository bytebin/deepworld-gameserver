module Deepworld
  module Obscenity
    def self.blacklist
      return @@blacklist if defined? @@blacklist

      words = IO.read(File.join(Deepworld::Loader.root, 'config', 'blacklist.txt')).split("\n").map do |word|
        word.downcase.gsub('_', '\s')
      end

      @@blacklist = /#{words.join('|')}/i
    end

    def self.unallowed_characters_regex
      letters = IO.read(File.join(Deepworld::Loader.root, 'config', 'chat_characters.txt')).gsub(/\n/, '')
      /[^\s#{Regexp.escape(letters)}]/
    end

    def self.sanitize(text)
      return text if text.length < 3

      @@unallowed_characters ||= unallowed_characters_regex

      found = []
      new_text = text.dup.gsub(@@unallowed_characters, '') + " "
      new_text.to_ascii.scan(blacklist) { found << Regexp.last_match }

      found.each do |m|
        new_text[m.offset(0)[0]..m.offset(0)[1]-1] = replacement(m.to_s)
      end

      new_text.chop!
      new_text
    end

    def self.replacement(word)
      if Deepworld::Env.test?
        word[0] + ("!" * (word.length-1))
      else
        word[0] + (['!','@','#','$','%','&'].sample(word.length - 1)).join
      end
    end

    def self.is_obscene?(word)
      (word + " ").to_ascii.match blacklist
    end
  end
end
