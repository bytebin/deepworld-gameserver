module Rubyhave
  class Sequence < Composite
    def behave
      @current_index = 0

      while true
        return @status = SUCCESS if children.length == 0

        @status = get_child(@current_index).tick
        @current_index += 1

        if @status == FAILURE
          return @status

        elsif @current_index == children.length
          return @status
        end
      end
    end
  end
end
