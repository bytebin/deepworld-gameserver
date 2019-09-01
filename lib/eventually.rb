module Eventually
  DEFAULT_RETRIES = 128
  DEFAULT_DELAY   = 1/64.0

  # Options include:
  # retries: Number of times to attempt to pass, defaulting to 128 (2 seconds)
  # delay: Delay between retry attempts, defaulting to 1/64 of a second
  def eventually options = {}, &block
    raise "you must pass a block to the eventually method" unless block_given?

    retries     = options[:retries]   || DEFAULT_RETRIES
    delay       = options[:delay]     || DEFAULT_DELAY
    last_error  = nil
    success     = nil
    try_no      = 0

    while try_no < retries
      begin
        try_no += 1
        block.call
        return
      rescue Exception => e
        last_error = e

        sleep delay
      end
    end
    raise last_error
  end
end
