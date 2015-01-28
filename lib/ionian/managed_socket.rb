require 'ionian/socket'

module Ionian
  
  # A socket manager that wraps an {Ionian::Socket} and can perform functions
  # like heartbeating and auto-reconnect.
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
      @kwargs = kwargs
      
      @match_handlers = []
      @error_handlers = []
      
      create_socket
    end
    
    # Close the socket.
    # Disables :auto_reconnect.
    def close
      @auto_reconnect = false
      @socket.close unless @socket.closed?
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
      @error_handlers << block unless @error_handlers.include? block
      @socket.register_error_handler &block if @socket
      block
    end
    
    alias_method :on_error, :register_error_handler
    
    # Unregister a block from being called when a {Ionian::IO#run_match} error
    # is raised.
    def unregister_error_handler &block
      @error_handlers.delete_if { |o| o == block }
      @socket.unregister_error_handler &block if @socket
      block
    end
    
    # Pass unhandled methods to @socket.
    # @see Ionian::Socket
    def method_missing meth, *args, &block
      @socket.__send__ meth, *args, &block
    end
    
    def respond_to_missing? meth, *args
      @socket.respond_to? meth, *args
    end
    
    
    private
    
    # Initialize or reinitialize @socket.
    def create_socket
      @socket = Ionian::Socket.new **@kwargs
      @socket.on_error &method(:socket_error_handler)
      @match_handlers.each { |h| @socket.register_match_handler &h }
      @error_handlers.each { |h| @socket.register_error_handler &h }
      
      @socket.run_match
    end
    
    # {Ionian::Socket#on_error} handler for @socket.
    def socket_error_handler e, socket
      if auto_reconnect
        @socket.close unless @socket.closed?
        create_socket
      else
        raise e unless e.is_a? EOFError or e.is_a? IOError
      end
    end
    
  end
end
