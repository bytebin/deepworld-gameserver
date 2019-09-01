class TransactionRefreshCommand < BaseCommand
  def execute
    Transaction.apply_pending player do |success|
      unless success
        EM.add_timer(5.0) do
          Transaction.apply_pending player do |success|
            unless success
              EM.add_timer(10.0) do
                Transaction.apply_pending player do |success|
                  unless success
                    EM.add_timer(15.0) do
                      Transaction.apply_pending player
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end