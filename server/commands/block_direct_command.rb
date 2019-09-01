class BlockDirectCommand < BaseCommand
  data_fields :x, :y

  def execute
    if servant = player.directing_servant
      servant.interact player, :direct, Vector2[@x, @y]
    end
  end
end
