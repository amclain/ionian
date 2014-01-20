module Ionian
  
  # A convenient wrapper for TCP, UDP, and Unix server sockets.
  class Server
    
    def initialize **kwargs, &block
      @accept_listeners = []
      register_accept_listener &block if block_given?
    end
    
    # Starts the socket server listening for connections.
    # Blocks registered with #register_accept_listener will
    # be run when a connection is accepted.
    def listen
    end
    
    # Shutdown the server socket and stop listening for connections.
    def close
    end
    
    # Register a block to be run when server accepts a client connection.
    # The connected client is passed to the block as an Ionain::Client.
    def register_accept_listener &block
      @accept_listeners << block unless @accept_listeners.include? block
      block
    end
    
    alias_method :on_accept, :register_accept_listener
    
    # Unregisters a socket accept notifier block.
    def unregister_accept_listener proc
      @accept_listeners.delete_if {|o| o == proc} 
      proc
    end
    
  end
  
end