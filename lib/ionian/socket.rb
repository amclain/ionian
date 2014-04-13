require 'ionian/extension/socket'

module Ionian
  
  # A convenient wrapper for TCP, UDP, and Unix client sockets.
  class Socket
    
    # IP address or URL of server.
    attr_reader :host
    
    # Remote port number.
    attr_reader :port
    
    # Local port number.
    attr_reader :bind_port
    
    # Returns a symbol of the type of protocol this socket uses:
    # :tcp, :udp, :unix
    attr_reader :protocol
    alias_method :protocol?, :protocol
    
    
    # Creates a new socket or wraps an existing socket.
    # 
    # Args:
    #   host:       IP or hostname to connect to. Can contain the port in the format "host:port".
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
    #   linger:     Set true to enable the SO_LINGER flag. When #close is called,
    #               waits for the send buffer to empty before closing the socket.
    #   expression: Overrides the #read_match regular expression for received data.
    def initialize existing_socket = nil, **kwargs
      @socket = existing_socket
      
      @ionian_listeners = []
      
      @expression = kwargs.fetch :expression, nil
      
      if existing_socket
        # Convert existing socket.
        @socket.extend Ionian::Extension::IO
        @socket.extend Ionian::Extension::Socket
        
        if existing_socket.is_a? UNIXSocket
          @host = existing_socket.path
          @port = nil
        else
          @host = existing_socket.remote_address.ip_address if existing_socket
          @port = existing_socket.remote_address.ip_port if existing_socket
        end
      
        if @socket.is_a? TCPSocket
          @protocol = :tcp
        elsif @socket.is_a? UDPSocket
          @protocol = :udp
        elsif @socket.is_a? UNIXSocket
          @protocol = :unix
        end
        
        @persistent     = true # Existing sockets are always persistent.
        
        @socket.expression = @expression if @expression
        
        initialize_socket_methods
        
      else
        # Initialize new socket.
        
        # Parse host out of "host:port" if specified.
        host_port_ary   = kwargs.fetch(:host).to_s.split ':'
        
        @host           = host_port_ary[0]
        @port           = kwargs.fetch :port, host_port_ary[1].to_i || 23
        @bind_port      = kwargs.fetch :bind_port,  @port
        
        # Automatically select UDP for the multicast range. Otherwise default to TCP.
        default_protocol = :tcp
        default_protocol = :udp  if Ionian::Extension::Socket.multicast? @host
        default_protocol = :unix if @host.start_with? '/'
        
        @protocol       = kwargs.fetch :protocol,   default_protocol
        @persistent     = kwargs.fetch :persistent, true
        @persistent     = true if @protocol == :udp
        
        @reuse_addr     = kwargs.fetch :reuse_addr, false
        @cork           = kwargs.fetch :cork,       false
        @no_delay       = kwargs.fetch :no_delay,   @persistent ? false : true
        
        # Default to false for persistent sockets, true for
        # nonpersistent sockets. When nonpersistent, the socket
        # should remain open to send data in the buffer after
        # close is called (typically right after write).
        @linger         = kwargs.fetch :linger,     @persistent ? false : true
      
        
        create_socket if @persistent
      end
    end
        
    # Returns the regular expression used to match incoming data.
    def expression
      @expression || @socket.expression
    end
    
    # Set the regular expression used to match incoming data.
    def expression= exp
      @expression = exp
      @socket.expression = exp if @socket
    end
    
    # Returns true if the socket remains open after writing data.
    def persistent?
      @persistent == false || @persistent == nil ? false : true
    end
    
    # Send a command (data) to the socket.
    # Returns an array of received matches.
    # Block yields received match.
    # See Ionian::Extension::IO#read_match.
    def cmd string, **kwargs, &block
      create_socket unless @persistent
      
      write string
      @socket.flush
      
      matches = @socket.read_match(kwargs) { |match| yield match if block_given? }
      @socket.close unless @persistent
      
      matches
    end
    
    # Register a block to be called when #run_match receives matched data.
    # Method callbacks can be registered with &object.method(:method).
    # Returns a reference to the given block.
    # block = ionian_socket.register_observer { ... }
    def register_observer &block
      @ionian_listeners << block unless @ionian_listeners.include? block
      @socket.register_observer &block if @socket
      block
    end
    
    alias_method :on_match, :register_observer
    
    # Unregister a block from being called when matched data is received.
    def unregister_observer &block
      @ionian_listeners.delete_if { |o| o == block }
      @socket.unregister_observer &block if @socket
      block
    end
    
    ### Methods Forwarded To @socket ###
    
    # Returns true if there is data in the receive buffer.
    # Args:
    #   Timeout: Number of seconds to wait for data until
    #     giving up. Set to nil for blocking.
    def has_data? **kwargs
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
    def puts *string
      self.write string.map{ |s| s.chomp }.join("\n") + "\n"
    end
    
    # Writes the given string to the socket. Returns the number of
    # bytes written.
    def write string
      create_socket unless @persistent
      
      num_bytes = 0
      
      if @protocol == :udp
        num_bytes = @socket.send string, 0
      else
        num_bytes = @socket.write string
      end
      
      unless @persistent
        @socket.flush
        
        # Read in data to prevent RST packets.
        # TODO: Shutdown read stream instead?
        @socket.read_all nonblocking: true
        
        # TODO: Sleep added so that data can be read on the receiving
        # end. Can this be changed to shutdown write?
        # Why isn't so_linger taking care of this?
        sleep 0.01
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
        
        @socket.no_delay = @no_delay
        @socket.cork = @cork
        
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
      
      @socket.linger = @linger
      
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
        .select { |m| @socket.respond_to? m }
        .select { |m| not self.respond_to? m }
        .each do |m|
          self.singleton_class.send :define_method, m do |*args, &block|
            @socket.__send__ m, *args, &block
          end
        end
      
      @socket_methods_initialized = true
    end
    
  end
end