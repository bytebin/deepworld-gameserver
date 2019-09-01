class AccessCode < MongoModel
  fields [:limit, :redemptions, :code]

  def available?
    (self.redemptions || 0) < self.limit
  end

  def redeem!(&block)
    self.inc(:redemptions, 1) do |a|
      yield a if block_given?
    end
  end

end