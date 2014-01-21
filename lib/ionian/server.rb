require 'socket'
require 'ionian/socket'

module Ionian
  
  # A convenient wrapper for TCP, UDP, and Unix server sockets.
  class Server
    
    def initialize **kwargs, &block
      @accept_listeners = []
      register_accept_listener &block if block_given?
      
      @interface = kwargs.fetch :interface, ''
      @port      = kwargs.fetch :port, nil
      
      
      # Automatically select UDP for the multicast range. Otherwise default to TCP.
      default_protocol = :tcp
      # TODO: This ivar may be incorrect for UDP -- bound interface is not destination.
      default_protocol = :udp  if Ionian::Extension::Socket.multicast? @interface
      default_protocol = :unix if @interface.start_with? '/'
      
      @protocol  = kwargs.fetch :protocol, default_protocol
      
      # TODO: Needs to account for different protocols.
      case @protocol
      when :tcp
        @server = TCPServer.new @port
      when :udp
        @server = Ionian::Socket.new host: @interface, port: @port, protocol: :udp
      when :unix
        @server = UNIXServer.new @interface
      end
    end
    
    # Starts the socket server listening for connections.
    # Blocks registered with #register_accept_listener will
    # be run when a connection is accepted.
    def listen
      @accept_thread = Thread.new do
        # Package in an Ionian::Socket
        client = Ionian::Socket.new @server.accept
        
        @accept_listeners.each do |listener|
          listener.call client
        end
      end
    end
    
    # Shutdown the server socket and stop listening for connections.
    def close
      @server.close if @server
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