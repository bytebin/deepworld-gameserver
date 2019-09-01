# Use this lib for a little inspiration: https://github.com/caolan/async
class Funky
  MAX_ITERATIONS = 100

  def self.until(test, function, iteration = 0, &block)
    raise "Until has reached maximum iteration count: #{MAX_ITERATIONS}" if iteration >= MAX_ITERATIONS

    if test.call
      yield
    else
      function.call Proc.new { self.until test, function, iteration + 1, &block }
    end
  end
end

