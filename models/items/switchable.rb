module Items
  class Switchable < Base

    def use!(params = {})
      # If switched type is configured as a string, use custom activator
      if @item.use.switched.is_a?(String)
        if clazz = "Items::#{@item.use.switched}".constantize
          @meta = @zone.get_meta_block(@position.x, @position.y)
          clazz.new(@player, @params.merge(meta: @meta)).use!(switch: params[:switch])
        end

      # Otherwise, just swap mod
      else
        new_mod = @params[:mod] % 2 == 0 ? @params[:mod] + 1 : @params[:mod] - 1 # Alternate odd and even mod
        @zone.update_block nil, @position.x, @position.y, FRONT, nil, new_mod, nil, :skip
      end
    end
  end
end