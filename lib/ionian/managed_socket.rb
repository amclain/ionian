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
      
      @socket = Ionian::Socket.new **kwargs
      
      @socket.on_error { |e|
        if auto_reconnect
          @socket.close unless @socket.closed?
          @socket = Ionian::Socket.new **kwargs
        else
          raise e unless e.is_a? EOFError or e.is_a? IOError
        end
      }
      
      @socket.run_match
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
    
  end
end
