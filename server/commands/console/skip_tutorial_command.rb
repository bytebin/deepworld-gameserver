class SkipTutorialCommand < BaseCommand
  include WorldCommandHelpers

  def execute
    # Jetpack, pickaxe, shovel
    player.inv.add(1060, 1, true)
    player.inv.add(601, 1, true)
    player.inv.add(1024, 1, true)

    EM.add_timer(0.1){ Teleportation.spawn!(player)}
  end
end
