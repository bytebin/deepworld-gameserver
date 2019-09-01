module Players
  module Admin

    def step_admin
      if admin?
        if @steps % 10 == 0
          #queue_message EventMessage.new('serverBenchmarks', Game.analyzed_benchmarks)
        end
      end
    end

  end
end
