class Array
  def median
    return nil if self.count == 0
    sorted = self.sort
    len = sorted.length
    return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end
