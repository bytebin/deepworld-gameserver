class MongoModel
  attr_accessor :id, :errors, :ephemeral

  ###################
  # Criteria generation methods
  ###################
  def self.all(&block)
    Criteria.new(self).all &block
  end

  def self.first(&block)
    Criteria.new(self).first &block
  end

  def self.random(amount = 1, &block)
    Criteria.new(self).random amount, &block
  end

  def self.each(&block)
    Criteria.new(self).each &block
  end

  def self.where(selector)
    Criteria.new(self).where(selector)
  end

  def self.or(selectors)
    Criteria.new(self).or(selectors)
  end

  def self.skip(amount)
    Criteria.new(self).skip(amount)
  end

  def self.limit(amount)
    Criteria.new(self).limit(amount)
  end

  def self.sort(field, asc_desc=1)
    Criteria.new(self).sort(field, asc_desc)
  end

  def self.fields(fields, field_type = nil)
    fields = [*fields]
    @attributes ||= []
    @attributes += fields

    unless field_type == false
      fields.each do |field|
        define_method("#{field}=") do |val|
          if field_type and !val.is_a?(field_type)
            val = field_type.parse(val)
          end

          instance_variable_set "@#{field}", val
        end

        define_method("#{field}") do
          instance_variable_get "@#{field}"
        end
      end
    end
  end

  def initialize(params={}, options={})
    assign_values(params)
    @errors = []

    # Get the id
    self.id = params['_id']

    after_initialize if self.id && respond_to?(:after_initialize) and options[:callbacks] != false
  end

  def run_callbacks
    after_initialize if respond_to?(:after_initialize)
    self
  end

  # Note, updates are inefficient and should track and only update changed items
  def save(fields = nil, &block)
    return if @ephemeral

    if @id
      attrs = attributes_hash.except('_id').inject({}){ |memo, (k, v)| memo[k] = v.respond_to?(:to_mongo) ? v.to_mongo : v; memo  }

      self.update(attrs) do
        yield self if block_given?
      end
    else
      @id = self.class.collection.insert(attributes_hash)
      yield obj if block_given?
    end
  end

  def update(params={}, in_place = true, &block)
    if @ephemeral
      self.assign_values(params)

    else
      self.class.update({'_id' => id}, params, in_place) do
        self.assign_values(params)
        yield self if block_given?
      end
    end
  end

  def inc(field, value, &block)
    params = {'$inc' => { field => value }}

    self.class.update({'_id' => id}, params, false) do
      self.assign_values(params)
      yield self if block_given?
    end
  end

  def push(field, value, &block)
    params = {'$push' => { field => value }}

    self.class.update({'_id' => id}, params, false) do
      self.assign_values(params)
      yield self if block_given?
    end
  end

  def upsert(params={}, in_place = true, &block)
    self.class.upsert({'_id' => id}, params, in_place) do
      self.assign_values(params) if block_given?
      yield self if block_given?
    end
  end

  def reload(fields = nil, &block)
    opts = fields ? { fields: [fields].flatten } : {}
    resp = self.class.collection.find_one({'_id' => self.id}, opts)

    resp.callback do |document|
      puts "I (#{self}) am nil #{Kernel.caller.join("\n")}" if (Deepworld::Env.development? and !document)
      self.assign_values(document)
      yield self if block_given?
    end

    resp.errback do |err|
      error! "Unable to reload #{self.class.name} with id of #{self.id}", err
    end
  end

  def epoch_id
    self.id.generation_time.to_i
  end

  def attributes
    self.class.attributes
  end

  def unset(*attrs, &block)
    attrs = [*attrs].inject({}){ |h,a| h[a.to_s] = 1; h }
    self.class.update({ '_id' => id }, { '$unset' => attrs }, false, &block)
  end

  def self.attributes
    @attributes
  end

  def attributes_hash
    attributes.inject({}) do |memo, key|
      memo[key] = self.send(key)
      memo
    end
  end

  def self.pluck(params={}, fields, &block)
    fields = [fields].flatten.map(&:to_s)
    cursor = collection.find(params, fields: [fields].flatten)

    resp = cursor.defer_as_a

    resp.callback do |documents|
      EM.defer do
        results = documents.map do |doc|
          fields.map {|f| doc[f]}
        end

        yield results if block_given?
      end
    end

    resp.errback do |err|
      error! "Unable to pluck with params #{params} and fields #{fields}"
    end
  end

  def self.find(params={}, options={}, &block)
    callbacks = options.delete(:callbacks)
    cursor = collection.find(params, options)

    resp = cursor.defer_as_a

    resp.callback do |documents|
      EM.defer do
        yield documents.map { |d| self.new(d, {callbacks: callbacks}) if d }
      end
    end

    resp.errback do |err|
      error! "Unable to find with params #{params}", err
    end
  end

  def self.each(params={}, options={}, &block)
    callbacks = options.delete(:callbacks)
    cursor = collection.find(params, options)

    cursor.each do |document|
      EM.defer do
        block.call(self.new(document, {callbacks: callbacks})) if document
      end
    end
  end

  def self.find_one(params={}, options={}, &block)
    callbacks = options.delete(:callbacks)
    resp = collection.find_one(params, options)

    resp.callback do |document|
      EM.defer do
        yield document ? self.new(document,  {callbacks: callbacks}) : nil
      end
    end

    resp.errback do |err|
      error! "Unable to find with params #{params}", err
    end
  end

  def self.find_by_id(id, options = {}, &block)
    self.find_one({'_id' => id}, options, &block)
  end

  def self.update(params, attributes, in_place = true, &block)
    if collection.update(params, in_place ? { '$set' => attributes } : attributes)
      yield if block_given?
    else
      error! "Couldn't update for #{params}"
    end
  end

  def self.update_all(params, attributes, in_place = true, &block)
    if collection.update(params, in_place ? { '$set' => attributes } : attributes, multi: true)
      yield if block_given?
    else
      error! "Couldn't update for #{params}"
    end
  end

  def self.upsert(params, attributes, in_place = true, &block)
    if collection.update(params, in_place ? { '$set' => attributes } : attributes, { upsert: true })
      yield if block_given?
    else
      error! "Couldn't upsert for #{params}"
    end
  end

  def self.create(params, &block)
    if doc_id = collection.insert(params)
      obj = self.new(params.merge('_id' => doc_id), {callbacks: false})
      yield obj if block_given?

      obj
    else
      error! "Could not create #{params}"
    end
  end

  def self.insert(params, &block)
    doc_ids = collection.insert(params)
    yield doc_ids if block_given?
  end

  def self.remove(params, &block)
    if collection.remove(params)
      yield if block_given?
    else
      error! "Couldn't remove for #{params}"
    end
  end

  def self.collect(field, &block)
    field = sanitize(field)
    gr = collection.group(initial: { field => [] }, reduce: "function(doc,out){ out.#{field}.push(doc.#{field}); }" )

    gr.callback do |obj|
      collected = obj.first.values.first rescue nil
      yield collected
    end

    gr.errback do |err|
      error! "Couldn't collect #{field}: #{obj}", err
    end
  end

  def self.count(params={}, &block)
    cursor = collection.find(params)
    cursor.count.callback do |c|
      yield c
    end
  end

  def self.connect
    options = {
      host: Deepworld::Settings.mongo.hosts.first.split(':')[0],
      port: Deepworld::Settings.mongo.hosts.first.split(':')[1],
      database: Deepworld::Settings.mongo.database}

    options[:username] = Deepworld::Settings.mongo.username if Deepworld::Settings.mongo.username
    options[:password] = Deepworld::Settings.mongo.password if Deepworld::Settings.mongo.password

    @@pool = ConnectionPool.new(options)
    @@pool.on_connected do
      yield if block_given?
    end
  end

  def self.collection_name
    @collection_name ||= self.name.underscore.pluralize
  end

  def self.collection
    @@pool.db[collection_name.to_s]
  end

  protected

  def assign_values(params)
    return self unless params

    # Assign values to accessors
    params.each do |k,v|
      if k[0] == '$'
        case k

        when '$set'
          v.each do |sk, sv|
            self.send("#{sk}=", sv) if attributes.include?(sk.to_sym)
          end

        when '$addToSet'
          v.each do |sk, sv|
            if attributes.include?(sk.to_sym)
              prev = self.send("#{sk}") || []
              self.send("#{sk}=", (prev + [sv]).flatten.uniq)
            end
          end

        when '$pull'
          v.each do |pk, pv|
            if attributes.include?(pk.to_sym)
              prev = self.send("#{pk}") || []
              prev.delete pv

              self.send("#{pk}=", prev)
            end
          end

        when '$push'
          v.each do |pk, pv|
            if attributes.include?(pk.to_sym)
              prev = self.send("#{pk}") || []
              prev.push pv

              self.send("#{pk}=", prev)
            end
          end


        when '$inc'
          v.each do |ik, iv|
            if attributes.include?(ik.to_sym)
              prev = self.send("#{ik}" || 0)
              self.send("#{ik}=", (prev || 0) + iv)
            end
          end
        end

      elsif k.match /\./
        hash, hash_key = k.to_s.split('.')
        self.send("#{hash}").send('[]=', hash_key, v)

      else
        self.send("#{k}=", v) if attributes.include?(k.to_sym)
      end
    end

    self
  end

  def error!(msg, err=nil)
    self.class.error!(msg, err)
  end

  def self.error!(msg, err=nil)
    raise msg
  end

  def self.sanitize(field)
    field.to_s.gsub(/[^\w]/, '')
  end
end
