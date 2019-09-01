module Rubyhave
  class BehaviorTree < Sequence

    def self.create(behaviors, entity)
      bt = self.new(nil, entity)

      behaviors.each do |behavior|
        if type = Rubyhave.behaviors[behavior['type'].to_sym]
          bt.add_child type.new(bt, entity, behavior.except('type'))
        else
          puts "Behavior #{behavior['type']} not defined."
        end
      end

      bt
    end

    def properties(key)
      @properties
    end
  end
end
