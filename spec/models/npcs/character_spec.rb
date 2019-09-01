require 'spec_helper'
include EntityHelpers

describe Character do

  before(:each) do
    with_a_zone
    with_a_player

    @ents = Hashie::Mash.new(YAML.load_file('spec/data/npcs.yaml'))
    Game.stub(:entity) do |ent|
      @ents[ent]
    end

    Game.stub(:fake).and_return('Norma')
    @entity = add_entity(@zone, 'automata/android', 1, Vector2[5, 5])
  end

  it 'should create a doc when spawned' do
    character = @entity.character
    character.entity.should eq @entity
    verify_character character
  end

  # it 'should not add character to mob count' do
  #   3.times { add_entity(@zone, 'automata/android', 1, Vector2[5, 5]) }
  #   @zone.mob_count.should eq 0
  # end

  it 'should save' do
    @entity.position = Vector2[10, 10]
    @entity.character.save!
    @entity.character.position.should eq Vector2[10, 10]
  end

  it 'should save with zone save' do
    @entity.position = Vector2[10, 10]
    @zone.persist!
    eventually do
      @entity.character.position.should eq [10, 10]
    end
  end

  it 'should load on zone spinup' do
    @entity.position = Vector2[10, 10]
    shutdown_zone(@zone)
    reactor_wait

    Game.stub(:fake).and_return('Jules')

    register_player(@zone)
    @reloaded_zone = Game.zones[@zone.id]
    characters = @reloaded_zone.characters.values
    characters.should_not be_blank
    characters.size.should eq 1
    verify_character characters.first.character, [10, 10]
  end

  def verify_character(character, position = [5, 5])
    character.should_not be_blank
    character.zone_id.should eq @zone.id
    character.ilk.should eq 150
    character.name.should eq 'Norma'
    character.position.should eq position
    character.metadata.should eq({})
  end

end