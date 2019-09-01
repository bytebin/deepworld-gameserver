module Rubyhave
  class Composite < Behavior
    def add_children(children)
      children.each {|c| add_child c }
      children
    end

    def add_child(child)
      child.parent = self
      children << child
      child.after_add
      child
    end

    def insert_child(index, child)
      child.parent = self
      children.insert index, child
      child.after_add
      child
    end

    def get_child(index)
      children[index]
    end

    def children
      @children ||= []
    end

    def react(message, params)
      children.each { |c| c.react message, params }
    end
  end
end