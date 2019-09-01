require 'rbconfig'

class OS
  class << self
    def is?(what)
      what === RbConfig::CONFIG['host_os']
    end

    def to_s
      RbConfig::CONFIG['host_os']
    end

    def linux?
      OS.is? /linux|cygwin/
    end

    def mac?
      OS.is? /mac|darwin/
    end
  end
end
