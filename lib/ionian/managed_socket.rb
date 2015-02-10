require 'ionian/socket'

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
      
      @match_handlers = []
      @error_handlers = []
      
      @write_queue = Queue.new
      @write_pipe_rx, @write_pipe_tx = IO.pipe
    end
    
    # --------------------------------------------------------------------------
    # TODO: Significantly simplify the ManagedSocket interface.
    #       Create a reactor loop that handles writing data and
    #       automatic reconnect.
    # --------------------------------------------------------------------------
    
    # Close the socket.
    # Disables :auto_reconnect.
    def close
      @auto_reconnect = false
      @socket.close if @socket and not @socket.closed?
      @write_pipe_tx.close
      @write_pipe_rx.close
      @write_queue = nil
    end
    
    # Start the event loop.
    # Should be called after the handlers are registered.
    def run
      create_socket unless @run_thread
      @run_thread ||= Thread.new do
        # p ::IO.select [@write_pipe_rx], nil, nil, nil
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
    # @return [Block] The given block.
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
    
    # Register a block to be called when {Ionian::Extension::IO#run_match}
    # raises an error.
    # Method callbacks can be registered with &object.method(:method).
    # @return [Block] a reference to the given block.
    # @yield [Exception, self]
    def register_error_handler &block
      raise NotImplementedError
      
      @error_handlers << block unless @error_handlers.include? block
      @socket.register_error_handler &block if @socket
      block
    end
    
    alias_method :on_error, :register_error_handler
    
    # Unregister a block from being called when a {Ionian::IO#run_match} error
    # is raised.
    def unregister_error_handler &block
      raise NotImplementedError
      
      @error_handlers.delete_if { |o| o == block }
      @socket.unregister_error_handler &block if @socket
      block
    end
    
    
    private
    
    # Initialize or reinitialize @socket.
    def create_socket
      begin
        @socket = Ionian::Socket.new **@kwargs
        
        @socket.on_error &method(:socket_error_handler)
        @match_handlers.each { |h| @socket.register_match_handler &h }
        @error_handlers.each { |h| @socket.register_error_handler &h }
        
        @socket.run_match
      rescue Errno::ECONNREFUSED, SystemCallError => e
        if auto_reconnect
          sleep @kwargs.fetch :connect_timeout, 10
          retry
        else
          raise e
        end
      end
    end
    
    # {Ionian::Socket#on_error} handler for @socket.
    def socket_error_handler e, socket
      if auto_reconnect
        @socket.close if @socket and not @socket.closed?
        create_socket
      else
        raise e unless e.is_a? EOFError or e.is_a? IOError
      end
    end
    
    def notify_match_handlers match
      @match_handlers.each { |h| h.call match, self }
    end
    
    def notify_error_handlers exception
      @error_handlers.each { |h| h.call exception, self }
    end
    
  end
end
