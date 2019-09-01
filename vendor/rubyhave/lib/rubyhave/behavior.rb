module Rubyhave
  class Behavior
    attr_reader :entity, :key, :properties
    attr_accessor :parent

    def initialize(root, entity, options={})
      @root     = root
      @entity   = entity
      @options  = options
      @key      = self.class.name.underscore.to_sym

      @last_behaved_at  = Time.at(0)
      @start_at         = Time.now + (@options['delay'] || 0)
      @status           = nil

      @should_benchmark = @entity.respond_to?(:behavior_benchmark)

      @locals = []
      @properties = {}
      @delta = 0

      on_initialize
    end

    def tick
      benchmark = Benchmark.measure do
        if can_behave?
          # unless ["BehaviorTree", "Selector"].include?(self.class.name.split('::')[1])
          #   puts "#{self.class.name.split('::')[1]} #{@entity.position}"
          # end
          @delta = Ecosystem.time - @last_behaved_at
          @last_behaved_at = Ecosystem.time
          @status = behave
        else
          @status = FAILURE
        end

        on_terminate if @status != RUNNING
      end

      @entity.behavior_benchmark self, benchmark.real if @should_benchmark

      @status
    end

    def running!
      return RUNNING
    end

    def behaved_within?(seconds)
      Ecosystem.time - @last_behaved_at <= seconds
    end


    # Properties

    def get(key)
      properties(key)[key.to_sym]
    end

    def set(key, value)
      properties(key)[key.to_sym] = value
    end

    def clear(key)
      properties(key).delete(key)
      nil
    end

    def has?(key)
      !properties(key)[key].nil?
    end

    def local(*props)
      @locals += props
    end

    def local?(key)
      @locals.include?(key)
    end

    def properties(key)
      raise "Can't access properties until parent is set" unless parent
      local?(key) ? @properties : parent.properties(key)
    end



    protected

    # ------------------------------------------
    # Override these
    # ------------------------------------------

    # Initialization
    def on_initialize
    end

    def after_add
    end

    # Termination
    def on_terminate
    end

    # Behavior
    def behave
      @status = SUCCESS
    end

    # Validation
    def can_behave?
      true
    end

    def behavior(key, opts = {})
      Rubyhave.behaviors[key.to_sym].new @root, @entity, @options.merge(opts)
    end

    def react(message, params)
    end
  end
end