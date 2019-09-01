module DialogHelpers
  # Return dialog ID and sections
  def receive_dialog(socket)
    msg = Message.receive_one(socket, only: :dialog)
    msg.should_not be_blank
    return msg.data[0], msg.data[1]['sections']
  end

  def respond_to_dialog(player, response = [])
    response = [response].flatten

    dialog_id, sections = receive_dialog(player.socket)
    command! player, :dialog, [dialog_id, response]
  end
end