class Criteria

  attr_reader :selector, :options

  def initialize(model_class)
    @model_class = model_class
    @selector = {}
    @options = {callbacks: true}
  end

  def all(&block)
    @model_class.find(@selector.dup, @options.dup, &block)
  end
  alias find all

  def first(&block)
    @model_class.find_one(@selector.dup, @options.dup, &block)
  end
  alias find_one first

  def random(amount = 1, &block)
    # Get the count
    cursor = @model_class.collection.find(@selector)
    cursor.count.callback do |c|
      exausted = false
      ids = []

      test = Proc.new do
        exausted || ids.length >= amount
      end

      function = Proc.new do |callback|
        skip = (rand * (c - ids.count)).to_i

        # Query, skipping collected IDs
        @model_class.collection.find_one(@selector.merge(_id: {'$nin' => ids}), skip: skip, fields: ['_id']).callback do |document|
          if document
            ids << document['_id']
          else
            exausted = true
          end

          callback.call
        end
      end

      Funky.until(test, function) do
        self.where(_id: { '$in' => ids}).all do |docs|
          yield docs
        end
      end
    end
  end

  def randomlight(amount = 1, &block)
    base_options = @options.dup

    fields(:_id).limit(@options[:limit] || 100).all do |docs|
      randoms = docs.random(amount).map(&:id)

      if randoms.present?       
        @model_class.where(_id: { '$in' => randoms }).fields(base_options[:fields]).callbacks(base_options[:callbacks]).all do |random_docs|
          yield random_docs
        end
      else
        yield []
      end
    end
  end

  def each(&block)
    @model_class.each(@selector, @options, &block)
  end

  def error!(msg, err=nil)
    err ? raise(err, msg) : raise(msg)
  end

  #####################
  # Builders
  #####################

  def where(selector)
    @selector.merge!(selector)

    self
  end

  def or(selectors)
    self.where({ '$or' => selectors })

    self
  end

  def fields(*fields)
    @options[:fields] = fields.flatten.map{|f| f.downcase.to_sym}
    self
  end

  def hint(idx)
    @options[:hint] = idx
    self
  end

  def skip(amount)
    @options[:skip] = amount
    self
  end

  def limit(amount)
    @options[:limit] = amount
    self
  end

  # Field to sort on, 1 for asc -1 for desc
  def sort(field, asc_desc=1)
    @options[:sort] = (@options[:sort] || []) + [field.downcase.to_sym, asc_desc == 1 ? :asc : :desc]
    self
  end

  def callbacks(enabled)
    @options[:callbacks] = enabled
    self
  end

  def to_s
    {selector: @selector, options: @options}
  end
end
