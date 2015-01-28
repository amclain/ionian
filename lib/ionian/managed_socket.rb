require 'ionian/socket'

module Ionian
  
  # A socket manager that wraps an {Ionian::Socket} and can perform functions
  # like heartbeating and auto-reconnect.
  class ManagedSocket
    
    # When true, automatically reconnect if the socket closes.
    attr_reader :auto_reconnect
    
    # @option kwargs [Boolean] :auto_reconnect (false) Automatically reconnect
    #   if the socket closes.
    # 
    # @see Ionian::Socket#initialize More optional parameters.
    def initialize **kwargs
      @auto_reconnect = kwargs.delete(:auto_reconnect) || false
      
      @socket = Ionian::Socket.new **kwargs
    end
    
    def method_missing meth, *args, &block
      @socket.__send__ meth, *args, &block
    end
    
    def respond_to_missing? meth, *args
      @socket.respond_to? meth, *args
    end
    
  end
end
