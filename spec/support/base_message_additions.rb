class BaseMessage
  def message?(message_symbol)
    ident.should == BaseMessage.ident_for(message_symbol)[0]
  end
end