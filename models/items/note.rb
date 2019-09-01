module Items
  class Note < Base

    def use(params = {})
      return unless @meta

      # Locational note
      if loc = @meta.data['l']
        text = @meta.data['t']
        notify({ sections: [ { title: "\n#{text}" }, { map: loc } ] }, 13)

      # Otherwise, send text if not owner
      elsif !@meta.player?(@player)
        text = %w{t1 t2 t3 t4 t5 t6}.inject(''){ |s,t| s += (@meta.data[t] || '') + ' '; s }.squeeze(' ')
        if text.present?
          @player.show_dialog [{ text: text }]
        end
      end
    end
  end
end