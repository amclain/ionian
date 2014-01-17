require 'ionian/extension/socket'

module Ionian
  
  # A convenient wrapper for TCP, UDP, and Unix sockets.
  class Socket
    attr_accessor :expression
    
    # Args:
    #   host:       IP or hostname to connect to.
    #   port:       Connection's port number. Default is 23. Unused by :unix protocol.
    #   protocol:   Type of socket to create. :tcp, :udp, :unix. Default is :tcp.
    #               :udp will be automatically selected for addresses in the multicast range.
    #   persistent: The socket remains open after data is sent if this is true.
    #               The socket closes after data is sent and a packet is received
    #               if this is false. Default is true.
    #   bind_port:  Local UDP port to bind to for receiving data, if different than
    #               the remote port being connected to.
    #   reuse_addr: Set true to enable the SO_REUSEADDR flag. Allows local address reuse.
    #   no_delay:   Set true to enable the TCP_NODELAY flag. Disables Nagle algorithm.
    #   cork:       Set true to enable the TCP_CORK flag. Buffers multiple writes
    #               into one segment.
    #   expression: Overrides the #read_match regular expression for received data.
    def initialize(**kwargs)
      @socket         = nil
      
      # TODO: Should be able to parse the port out of host.
      #       :port should override this parsed value.
      
      @host           = kwargs.fetch :host
      @port           = kwargs.fetch :port,       23
      @bind_port      = kwargs.fetch :bind_port,  @port
      
      # Automatically select UDP for the multicast range. Otherwise default to TCP.
      default_protocol = :tcp
      default_protocol = :udp  if Ionian::Extension::Socket.multicast? @host
      default_protocol = :unix if @host.start_with? '/'
      
      @protocol       = kwargs.fetch :protocol,   default_protocol
      @persistent     = kwargs.fetch :persistent, true
      @expression     = kwargs.fetch :expression, nil
      
      @reuse_addr     = kwargs.fetch :reuse_addr, false
      @no_delay       = kwargs.fetch :no_delay,   false
      @cork           = kwargs.fetch :cork,       false
      
      @ionian_listeners = []
      
      create_socket if @persistent
    end
        
    # Returns a symbol of the type of protocol this socket uses:
    # :tcp, :udp, :unix
    def protocol?
      @protocol
    end
    
    # Returns true if the socket remains open after writing data.
    def persistent?
      @persistent == false || @persistent == nil ? false : true
    end
    
    # Send a command (data) to the socket.
    # Returns an array of received matches.
    # Block yields received match.
    # See Ionian::Extension::IO#read_match.
    def cmd(string, **kwargs, &block)
      create_socket unless @persistent
      
      if @protocol == :udp
        @socket.send string, 0
      else
        @socket.write string
      end
      
      @socket.flush
      
      matches = @socket.read_match(kwargs) {|match| yield match if block_given?}
      @socket.close unless @persistent
      
      matches
    end
    
    # Register a block to be called when #run_match receives matched data.
    # Method callbacks can be registered with &object.method(:method).
    # Returns a reference to the given block.
    # block = ionian_socket.register_observer {...}
    def register_observer &block
      @ionian_listeners << block unless @ionian_listeners.include? block
      @socket.register_observer &block if @socket
      block
    end
    
    alias_method :on_match, :register_observer
    
    # Unregister a block from being called when matched data is received.
    def unregister_observer(&block)
      @ionian_listeners.delete_if {|o| o == block}
      @socket.unregister_observer &block if @socket
      block
    end
    
    ### Methods Forwarded To @socket ###
    
    # Returns true if there is data in the receive buffer.
    # Args:
    #   Timeout: Number of seconds to wait for data until
    #     giving up. Set to nil for blocking.
    def has_data?(**kwargs)
      return false unless @socket
      @socket.has_data? kwargs
    end
    
    # Returns true if the socket is closed.
    def closed?
      return true unless @socket
      @socket.closed?
    end
    
    # Flushes buffered data to the operating system.
    # This method has no effect on non-persistent sockets.
    def flush
      @socket.flush if @persistent
    end
    
    # Writes the given string(s) to the socket and appends a
    # newline character to any string not already ending with one.
    def puts(*string)
      self.write string.map{|s| s.chomp}.join("\n") + "\n"
    end
    
    # Writes the given string to the socket. Returns the number of
    # bytes written.
    def write(string)
      create_socket unless @persistent
      
      num_bytes = 0
      
      if @protocol == :udp
        num_bytes = @socket.send string, 0
      else
        num_bytes = @socket.write string
      end
      
      unless @persistent
        # Read in data to prevent RST packets.
        has_data = ::IO.select [@socket], nil, nil, 0
        @socket.readpartial 0xFFFF if has_data
        
        @socket.close
      end
      
      num_bytes
    end
    
    alias_method :<<, :write
    
    
    private
    
    # Initialize or reinitialize @socket.
    def create_socket
      @socket.close if @socket and not @socket.closed?
      
      case @protocol
      when :tcp
        @socket = ::TCPSocket.new @host, @port
        @socket.extend Ionian::Extension::Socket
        @socket.expression = @expression if @expression
        @socket.no_delay = true if @no_delay
        @socket.cork = true if @cork
        
      when :udp
        @socket = ::UDPSocket.new
        @socket.extend Ionian::Extension::Socket
        
        @socket.reuse_addr = true if
          @reuse_addr or Ionian::Extension::Socket.multicast? @host
        
        @socket.bind ::Socket::INADDR_ANY, @bind_port
        @socket.connect @host, @port
        
        @socket.ip_add_membership if Ionian::Extension::Socket.multicast? @host
        
      when :unix
        @socket = ::UNIXSocket.new @host
        @socket.extend Ionian::Extension::Socket
      end
      
      # TODO: Implement SO_LINGER flag for non-persistent sockets;
      #       especially send-and-forget.
      
      @socket.expression = @expression if @expression
      
      # Register listeners.
      @ionian_listeners.each { |proc| @socket.on_match &proc }
      
      initialize_socket_methods
    end
    
    # Expose the @socket methods that haven't been defined by this class.
    # Only do this once for performance -- when non-persistent sockets are
    # recreated, they should be of the same type of socket.
    def initialize_socket_methods
      # Only initialize once, lazily.
      # For non-persistent sockets, this forwards the socket methods
      # the first time data is sent -- when the new socket is created.
      return if @socket_methods_initialized
      
      # Forward undefined methods to @socket.
      # This was chosen over method_missing to avoid traversing the object
      # hierarchy on every method call, like transmitting data.
      @socket.methods
        .select {|m| @socket.respond_to? m}
        .select {|m| not self.respond_to? m}
        .each do |m|
          self.singleton_class.send :define_method, m do |*args, &block|
            @socket.__send__ m, *args, &block
          end
        end
      
      @socket_methods_initialized = true
    end
    
  end
end