module BSON
  class ObjectId
    def digest(spread = 2048)
      1 + PearsonHashing.digest16(self.data.join) % (spread - 1)
    end
  end
end
