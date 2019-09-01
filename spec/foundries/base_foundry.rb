require 'securerandom'
require 'active_support/inflector'

class BaseFoundry
  def self.create(params = {}, options = {})
    options = { callbacks: true }.merge(options)

    params = self.build(params).inject({}){ |hash,pair| hash[pair[0]] = pair[1].respond_to?(:to_mongo) ? pair[1].to_mongo : pair[1]; hash  }

    object_id = collection.insert(params)
    object = collection.find_one(object_id)

    class_name.constantize.new(object, options)
  end

  def self.build(params = {})
    raise "Dude (or lady), you'll need to define build on your foundry"
  end

  def self.many!(count, params = {})
    count.times.collect{ |i| create(params) }
  end

  def self.reload(object)
    reloaded = collection.find_one(object.id)
    object = class_name.constantize.new(reloaded)
  end

  private

  def self.class_name
    self.name[0..-8]
  end

  def self.collection
    return @collection if @collection

    conn = Mongo::Connection.new(*Deepworld::Settings.mongo.hosts.first.split(':'))
    db   = conn[Deepworld::Settings.mongo.database]

    @collection = db[class_name.underscore.pluralize]
    @collection
  end
end