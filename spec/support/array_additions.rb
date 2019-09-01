class Array
  def messages?(*message_symbols)
    self.collect(&:ident).should == BaseMessage.ident_for(message_symbols)
  end

  def of_type(*message_symbols)
    msg = self.select{|m| BaseMessage.ident_for(message_symbols).include?(m.ident)}
  end
end