require 'socket'
require 'ionian/socket'

Thread.abort_on_exception = true


module Ionian
  
  # A convenient wrapper for TCP, UDP, and Unix server sockets.
  class Server
    
    # Interface to listen for clients.
    attr_reader :interface
    
    # Port number to listen for clients.
    attr_reader :port
    
    # Returns a symbol of the type of protocol this socket uses:
    # :tcp, :udp, :unix
    attr_reader :protocol
    alias_method :protocol?, :protocol
    
    
    # A convenient wrapper for TCP and Unix server sockets (UDP doesn't use
    # a server).
    #
    # Accepts an optional block that is passed to #register_accept_listener.
    # Server opens listening socket on instantiation if this block is provided.
    # 
    # Args:
    #   port:           Port number to listen for clients.
    #   interface:      The address of the network interface to bind to.
    #                   Defaults to all.
    #   protocol:       :tcp, :unix. Default is :tcp.
    def initialize **kwargs, &block
      @accept_listeners = []
      register_accept_listener &block if block_given?
      
      # @interface = kwargs.fetch :interface, nil
      @interface = kwargs.fetch :interface, nil
      @port      = kwargs.fetch :port, nil
      
      # Automatically select UDP for the multicast range. Otherwise default to TCP.
      default_protocol = :tcp
      
      if @interface
        # TODO: This ivar may be incorrect for UDP -- bound interface is not destination.
        default_protocol = :udp  if Ionian::Extension::Socket.multicast? @interface
        default_protocol = :unix if @interface.start_with? '/'
      end
      
      @protocol  = kwargs.fetch :protocol, default_protocol
      
      
      # TODO: Move this to #listen.
      case @protocol
      when :tcp
        @interface ||= '0.0.0.0' # All interfaces.
        
        # Parse host out of "host:port" if specified.
        host_port_ary = @interface.to_s.split ':'
        @interface = host_port_ary[0]
        @port ||= host_port_ary[1]
        
        raise ArgumentError, "Port not specified." unless @port
        @port = @port.to_i
        
        @server = TCPServer.new @interface, @port
        @server.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, [1].pack('i')
        
      when :udp
        raise ArgumentError, "UDP should be implemented with Ionian::Socket."
        
      when :unix
        raise ArgumentError, "Path not specified." unless @interface
        
        @server = UNIXServer.new @interface
      end
      
      listen if block_given?
    end
    
    # Starts the socket server listening for connections.
    # Blocks registered with #register_accept_listener will
    # be run when a connection is accepted.
    def listen &block
      register_accept_listener &block if block_given?
      
      @accept_thread ||= Thread.new do
        loop do
          # Package in an Ionian::Socket
          begin
            client = Ionian::Socket.new @server.accept
            @accept_listeners.each { |listener| listener.call client }
          rescue Errno::EBADF
            # This ignores the connection if the client closed it before it
            # could be accepted.
          rescue IOError
            # This ignores the connection if the client closed it before it
            # could be accepted.
          end
        end
      end
    end
    
    # Shutdown the server socket and stop listening for connections.
    def close
      @server.close if @server
      @accept_thread.kill if @accept_thread
      @accept_thread = nil
    end
    
    # Returns true if the server listener socket is closed.
    def closed?
      @server.closed?
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
      @accept_listeners.delete_if { |o| o == proc }
      proc
    end
    
  end
  
end