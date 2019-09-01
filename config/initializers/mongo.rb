module EM
  module Mongo
    class Database

      def [](collection_name)
        self.collection(collection_name)
      end
    end
    
    # Log mongo calls to stdout
    if ENV['MLOG'] == 'true'
      OPERATIONS = {
        '1' => 'OP_REPLY',
        '1000' => 'OP_MSG', 
        '2001' => 'OP_UPDATE',
        '2002' => 'OP_INSERT',
        '2004' => 'OP_QUERY',
        '2005' => 'OP_GET_MORE',
        '2006' => 'OP_DELETE',
        '2007' => 'OP_KILL_CURSORS'}

      class EMConnection
        def send_command(op, message, options={}, &cb)
          puts "Mongo #{OPERATIONS[op.to_s]}, #{message}"
          
          request_id, buffer = prepare_message(op, message, options)

          callback do
            send_data buffer
          end

          @responses[request_id] = cb if cb
          request_id
        end 
      end
    end
  end
end
