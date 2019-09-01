# Console command: display zone information
class WorldInfoCommand < BaseCommand
  include WorldCommandHelpers

  def execute
    if zone.locked
      notify({sections: [{ 'title' => 'This world is locked.', text: 'You can unlock it with a World Key, available as loot or in the store. Once unlocked, you can add/remove members or make your world public.' }]}, 1)

    else
      Player.get(zone.members + zone.owners, [:name]) do |members|
        mems = members.present? ? members.map{|m| m.name}.sort.join(', ') : " "

        player.show_dialog [
          { 'title' => 'World Info'},
          { 'text' => ' '},
          { 'text-color' => '4d5b82', 'text' => "Entry code" },
          { 'text' => zone.entry_code.present? ? zone.entry_code : "Use /wrecode to generate an entry code" },
          { 'text' => ' '},
          { 'text-color' => '4d5b82', 'text' => "Members" },
          { 'text' => mems }
        ]
      end
    end
  end

  def validate
    run_if_valid :validate_owner
  end

  def fail
    alert @errors.join(', ')
  end
end
