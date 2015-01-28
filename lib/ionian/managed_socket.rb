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
      create_socket
    end
    
    def close
      @auto_reconnect = false
      @socket.close unless @socket.closed?
    end
    
    # TODO: Intercept
    # def on_match &block
    # end
    
    # TODO: Intercept
    # def on_error &block
    # end
    
    def method_missing meth, *args, &block
      @socket.__send__ meth, *args, &block
    end
    
    def respond_to_missing? meth, *args
      @socket.respond_to? meth, *args
    end
    
    
    private
    
    def create_socket
      @socket = Ionian::Socket.new **@kwargs
      @socket.on_error &method(:socket_error_handler)
      @socket.run_match
    end
    
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
