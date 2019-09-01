module Dispatch
  class Dispatcher

    def initialize
      @redis = EM::Hiredis.connect(Deepworld::Configuration.redis_url)
      subscribe
      query_schedule
    end

    def subscribe
      @redis.pubsub.subscribe "server:global" do |msg|
        handle JSON.parse(msg)
      end
    end

    def query_schedule
      @redis.keys "server:global:schedule:*" do |keys|
        keys.each do |key|
          @redis.get key do |val|
            handle JSON.parse(val)
          end
        end
      end
    end


    private

    def handle(msg)
      begin
        puts "[Dispatcher] Handle: #{msg}"
        handler = "Dispatch::#{msg["handler"].camelize}".constantize.new
        handler.execute(msg["params"])
      rescue
        puts $!
        puts $!.backtrace.first(5)
      end
    end

  end

end
