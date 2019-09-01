module Players
  module Dialogs

    def show_dialog(config, respondable = true, respondable_data = nil, &block)
      @dialog_id ||= 0
      @dialog_id += 1

      config = { 'sections' => config } if config.is_a?(Array)
      @dialogs[@dialog_id] = Dialog.new(self, config, respondable_data, block) if respondable
      queue_message DialogMessage.new(@dialog_id, config)
    end

    def respond_to_dialog(dialog_id, values)
      if dialog = @dialogs[dialog_id]
        dialog.process_response values
        @dialogs.delete dialog_id

        if dialog.form && dialog.form.errors.present? && dialog.config['show_errors']
          error_dialog = { sections: [{ title: "Error:" }] + dialog.form.errors.map{ |err| { text: "- #{err}" }} }
          show_dialog error_dialog, true do |ok|
            show_dialog dialog.config, true do |a,b|
              dialog.block.call a, b
            end
          end
        end
      end
    end

    def show_modal_message(msg)
      show_dialog [{ 'text' => msg }], false
    end

    def show_android_dialog(sections_or_text, android_name, actions = ['Okay'], &block)
      title = "#{android_name} says:"

      config = {
        'sections' => sections_or_text.is_a?(String) ? [{ 'text' => interpolate_dialog_text(sections_or_text) }] : sections_or_text,
        'actions' => actions,
        'type' => 'android',
        'title' => title
      }

      config['sections'][0]['title'] = config.delete('title') if v2?

      show_dialog config, true, nil, &block
    end

    def interpolate_dialog_text(text)
      (text || " ").gsub(/\$family_name/, @family_name || '')
    end

    def confirm_with_dialog(msg, &block)
      cfg = { 'sections' => [{'text' => msg }], 'actions' => 'yesno' }
      show_dialog cfg, true do
        yield
      end
    end

  end
end
