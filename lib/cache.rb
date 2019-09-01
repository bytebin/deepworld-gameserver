class Cache
  def initialize
    @data = {}
  end
  
  # Retrive the data for a key, only if its within a specified age
  # Store the contents of the block as the value if not found 
  def get(key, max_age = 0, &block)
    if (value = @data[key.to_sym]) && (max_age == 0 || Time.now - value[0] <= max_age)
      value[1]
    else
      set(key, yield) if block_given?
    end
  end

  def set(key, value)
    @data[key.to_sym] = [Time.now, value]
    value
  end

  def clear!
    @data.clear
  end

  def clear(keys)
    [keys].flatten.compact.map do |key|
      @data.delete(key.to_sym)
    end
  end

end