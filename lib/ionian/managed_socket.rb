require 'ionian/socket'

Thread.abort_on_exception = true

module Ionian
  
  # A socket manager that performs functions like heartbeating and auto-reconnect.
  class ManagedSocket
    
    # When true, automatically reconnect if the socket closes.
    attr_reader :auto_reconnect
    
    # @option kwargs [Boolean] :auto_reconnect (false) Automatically reconnect
    #   if the socket closes. Must call {#close} to break the auto-reconnect
    #   loop.
    # 
    # @see Ionian::Socket#initialize More optional parameters.
    def initialize **kwargs
      @auto_reconnect = kwargs.delete(:auto_reconnect) || false
      raise NotImplementedError, ':auto_reconnect must be set true.' unless @auto_reconnect
      @kwargs = kwargs
      
      @match_handlers  = []
      @status_handlers = []
      
      @write_queue = Queue.new
      @write_pipe_rx, @write_pipe_tx = IO.pipe
      @write_pipe_rx.extend Ionian::Extension::IO
    end
    
    # Close the socket.
    # Disables :auto_reconnect.
    def close
      unless @closed == true
        @auto_reconnect = false
        @socket.close if @socket and not @socket.closed?
        @write_pipe_tx.close rescue IOError
        @write_pipe_rx.close rescue IOError
        @write_queue = nil
        
        @closed = true
      end
    end
    
    # Start the event loop.
    # Should be called after the handlers are registered.
    def run
      @run_thread ||= Thread.new do
        while not @write_pipe_rx.closed?
          begin
            create_socket if (not @socket or @socket.closed?) and not @write_pipe_rx.closed?
            io = ::IO.select([@write_pipe_rx, @socket.fd], nil, nil, nil).first.first
            
            case io
            
            when @write_pipe_rx
              @write_pipe_rx.read_all
              while @socket and not @write_queue.empty?
                @socket.write @write_queue.shift
              end
              
            when @socket.fd
              @socket.read_match
              
            end
          rescue IOError # Far-end socket closed.
            @socket.close if @socket and not @socket.closed?
          end
        end
      end
    end
    
    # Write data to the socket.
    def write data
      @write_queue << data
      @write_pipe_tx.write "\n"
    end
    
    # Register a block to be called when {Ionian::Extension::IO#run_match}
    # receives matched data.
    # Method callbacks can be registered with &object.method(:method).
    # @return [Block] the given block.
    # @yield [MatchData, self]
    def register_match_handler &block
      @match_handlers << block unless @match_handlers.include? block
      @socket.register_match_handler &block if @socket
      block
    end
    
    alias_method :on_match, :register_match_handler
    
    # Unregister a block from being called when matched data is received.
    def unregister_match_handler &block
      @match_handlers.delete_if { |o| o == block }
      @socket.unregister_match_handler &block if @socket
      block
    end
    
    # Register a block to be called when there is a change in socket status.
    # Method callbacks can be registered with &object.method(:method).
    # @return [Block] a reference to the given block.
    # @yield [status, self]
    def register_status_handler &block
      raise NotImplementedError
    end
    
    alias_method :on_status_change, :register_status_handler
    
    # Unregister a block from being called when there is a change in socket status.
    def unregister_status_handler &block
      raise NotImplementedError
    end
    
    
    private
    
    # Initialize or reinitialize @socket.
    def create_socket
      begin
        @socket = Ionian::Socket.new **@kwargs
        
        @match_handlers.each { |h| @socket.register_match_handler &h }
      rescue Errno::ECONNREFUSED, SystemCallError => e
        if auto_reconnect
          sleep @kwargs.fetch :connect_timeout, 10
          retry
        else
          raise e
        end
      end
    end
    
  end
end
