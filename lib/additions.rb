require 'pearson-hashing'

# class OpenSSL::Digest::Digest < OpenSSL::Digest
#   def initialize(*args)
#     warn('Digest::Digest is deprecated; use Digest')
#     puts Kernel.caller
#     super(*args)
#   end
# end

class Object
  def send_safe(*args)
    method = args.first.to_sym
    if method != :name && MongoModel.methods.include?(method)
      raise "Unsafe method called: #{args}"
    else
      send *args
    end
  end
end

class Numeric
  def minutes
    self * 60
  end

  def hours
    self * 3600
  end

  def binary_string(digits = 16)
    digits.times.collect { |i| (self >> i) & 1 }.reverse.join
  end
end

class Array
  def upsert_subarray(id)
    subarray = find{ |s| s[0] == id }
    unless subarray
      subarray = [id]
      self << subarray
    end
    subarray
  end

  def increment_subarray(id, amt = 1)
    arr = upsert_subarray(id)
    arr[1] ||= 0
    arr[1] += 1
  end

  def x
    self[0]
  end

  def y
    self[1]
  end
end

module Math
  def self.within_range?(pos1, pos2, range)
    return false unless pos1 && pos2 && range
    #Math.hypot(pos1.x - pos2.x, pos1.y - pos2.y) <= range
    ZoneKernel::Util.within_range?(pos1.x, pos1.y, pos2.x, pos2.y, range)
  end
end

class String
  def normalize(downcase = true)
    downcase ? self.squeeze(' ').strip.downcase : self.squeeze(' ').strip
  end
end

# ----------------
# msgpack
# ----------------
Time.class_eval do
  def to_msgpack(out='')
    ("Time[" + self.to_s + "]").to_msgpack(out)
  end
end

DateTime.class_eval do
  def to_msgpack(out='')
    ("DateTime[" + self.to_s + "]").to_msgpack(out)
  end
end

Date.class_eval do
  def to_msgpack(out='')
    ("Date[" + self.to_s + "]").to_msgpack(out)
  end
end
