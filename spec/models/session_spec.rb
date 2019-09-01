require 'spec_helper'

describe Player do
  describe 'With a zone and player' do
    before(:each) do
      with_a_zone
      with_a_player(@zone)
    end

    def get_session(must_be_ended = false)
      session = nil
      eventually {
        s = collection(:sessions).find_one(player_id: @one.id)
        s.should_not be_nil
        if must_be_ended
          s['ended_at'].should_not be_nil
        end
        session = s
      }
      session
    end

    it 'should create my first session on login' do
      session = get_session
      session['first'].should eq true
      session['cnt'].should be_nil
      @one.current_session.id.should eq session['_id']
    end


    it 'should finalize my first session on first logoff' do
      time_travel 1.minute
      disconnect @one.socket

      session = get_session(true)
      session['duration'].should eq 60
      session['first'].should eq true
      session['cnt'].should eq 1

      collection(:players).find({ '_id' => @one.id }).to_a.last['activation_at'].should be_nil
    end

    it 'should append to a session for my play' do
      time_travel 1.minute
      disconnect @one.socket
      session = get_session(true)

      # Wait
      time_travel 1.minute

      # Log back in and "play for a minute"
      @one, @o_sock = login(@zone, @one.id)
      time_travel 1.minute
      disconnect @one.socket

      session = get_session(true)
      session = collection(:sessions).find_one
      session['duration'].should eq 180
      session['first'].should eq true
      session['cnt'].should eq 2

      collection(:players).find({ '_id' => @one.id }).to_a.last['activation_at'].should be_nil
    end

    it 'should create a new session for my play' do
      # Play for a minute
      time_travel 1.minute
      disconnect @one.socket
      eventually { collection(:sessions).count.should eq 1 }

      # Go and poop for a bit
      time_travel 301.seconds
      activated = Time.now.dup

      # Play again
      @one, @t_sock = login(@zone, @one.id)
      time_travel 1.minute
      disconnect @one.socket

      eventually {
        collection(:sessions).count.should eq 2

        sessions = collection(:sessions).find.to_a
        sessions.map{|s| s['duration']}.should eq [60, 60]
        sessions.map{|s| s['first']}.should eq [true, nil]
        sessions.map{|s| s['cnt']}.should eq [1,1]

        collection(:players).find({ '_id' => @one.id }).to_a.last['activation_at'].should be_within(1.second).of activated
      }
    end

    it 'should mark activated only on the initial secondary session' do
       # Play for a minute
      time_travel 1.minute
      disconnect @one.socket
      eventually { collection(:sessions).count.should eq 1 }

      # Two more sessions
      time_travel 301.seconds
      activated = Time.now.dup
      @two, @t_sock = login(@zone, @one.id)
      time_travel 1.minute
      disconnect @two.socket
      eventually {
        collection(:sessions).count.should eq 2
      }

      time_travel 301.seconds
      @two, @t_sock = login(@zone, @one.id)
      time_travel 1.minute
      disconnect @two.socket
      eventually {
        collection(:sessions).count.should eq 3
      }

      collection(:players).find({ '_id' => @one.id }).to_a.last['activation_at'].should be_within(1.second).of activated
    end
  end
end