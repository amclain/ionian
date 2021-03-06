require 'timeout'
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
    
    # @return [Ionian::Socket] a broadcast socket.
    # 
    # @option kwargs [Fixnum] :port Port to broadcast on.
    # @option kwargs [String] :address ('255.255.255.255') Address to broadcast on.
    # 
    # @see #initialize Full list of socket options.
    def self.create_broadcast_socket **kwargs
      kwargs[:host] = kwargs.delete(:address) || '255.255.255.255'
      kwargs[:broadcast] = true
      new **kwargs
    end
    
    # Creates a new socket or wraps an existing socket.
    # 
    # 
    # @param existing_socket [Socket] An instantiated socket to be wrapped in
    #   and returned as an {Ionian::Socket} (for example, TCPSocket). A new
    #   socket will be created if this parameter is nil.
    # 
    # 
    # @param kwargs [Hash] :host is mandatory.
    # 
    # @option kwargs [String] :host IP or hostname to connect to.
    #   Can contain the port in the format "host:port".
    # 
    # @option kwargs [Fixnum] :port (23) Connection's port number. Unused by the
    #   :unix protocol.
    # 
    # @option kwargs [:tcp, :udp, :unix] :protocol (:tcp) Type of socket to create.
    #   :udp will be automatically selected for addresses in the multicast
    #   range, or if the broadcast flag is set.
    # 
    # @option kwargs [Fixnum] :connect_timeout (nil) Number of seconds to wait
    #   when connecting before timing out. Raises Errno::EHOSTUNREACH.
    # 
    # @option kwargs [Boolean] :persistent (true) The socket remains open after
    #   data is sent if this is true. The socket closes after data is sent and
    #   a packet is received if this is false.
    # 
    # @option kwargs [Boolean] :bind_port (:port) Local UDP port to bind to for
    #   receiving data, if different than the remote port being connected to.
    # 
    # @option kwargs [Boolean] :broadcast (false) Enable the SO_BROADCAST flag.
    #   Sets protocol to :udp implicitly.
    # 
    # @option kwargs [Boolean] :reuse_addr (false) Enable the SO_REUSEADDR flag.
    #   Allows local address reuse.
    # 
    # @option kwargs [Boolean] :no_delay (false) Enable the TCP_NODELAY flag.
    #   Disables Nagle algorithm.
    # 
    # @option kwargs [Boolean] :cork (false) Enable the TCP_CORK flag.
    #   Buffers multiple writes into one segment.
    # 
    # @option kwargs [Boolean] :linger (false) Enable the SO_LINGER flag.
    #   When #close is called, waits for the send buffer to empty before closing
    #   the socket.
    # 
    # @option kwargs [Regexp, String] :expression Overrides the
    #   {Ionian::Extension::IO#read_match} regular expression for received data.
    # 
    # 
    # @yieldparam socket [Ionian::Socket] This socket is yielded to the block.
    #   Socket flushes and closes when exiting the block.
    # 
    def initialize existing_socket = nil, **kwargs, &block
      @socket = existing_socket
      
      @ionian_match_handlers = []
      @ionian_error_handlers = []
      
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
        
        @persistent = true # Existing sockets are always persistent.
        
        @socket.expression = @expression if @expression
        
        initialize_socket_methods
        
      else
        # Initialize new socket.
        
        # Parse host out of "host:port" if specified.
        host_port_array = kwargs.fetch(:host).to_s.split ':'
        
        @host           = host_port_array[0]
        @port           = kwargs.fetch :port, (host_port_array[1] || 23).to_i
        @bind_port      = kwargs.fetch :bind_port, @port
        @connect_timeout = kwargs.fetch :connect_timeout, nil
        
        @broadcast      = kwargs.fetch :broadcast, false
        
        # Automatically select UDP for the multicast range. Otherwise default to TCP.
        default_protocol = :tcp
        default_protocol = :udp  if Ionian::Extension::Socket.multicast? @host
        default_protocol = :unix if @host.start_with? '/'
        default_protocol = :udp  if @broadcast
        
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
        # @linger         = kwargs.fetch :linger,     @persistent ? false : true
        # TODO: For some reason linger = true is causing tests to fail.
        @linger         = kwargs.fetch :linger,     false
      
        
        create_socket if @persistent
      end
      
      if block
        block.call self
        unless self.closed?
          self.flush
          self.close
        end
      end
    end
    
    # @return [IO] the file descriptor for this socket.
    #   For use with methods like IO.select.
    def fd
      @socket
    end
        
    # @return [Regexp] the regular expression used to match incoming data.
    def expression
      @expression || @socket.expression
    end
    
    # Set the regular expression used to match incoming data.
    # @param exp [Regexp, String] Match expression.
    # @see Ionian::Extension::IO#expression=
    def expression= exp
      @expression = exp
      @socket.expression = exp if @socket
    end
    
    # @return [Boolean] True if the socket remains open after writing data.
    def persistent?
      @persistent == false || @persistent == nil ? false : true
    end
    
    # Send a command (data) to the socket.
    # 
    # @param [Hash] kwargs Pass through to {Ionian::Extension::IO#read_match}.
    # 
    # @return [Array<MatchData>] An array of received matches.
    # 
    # @yieldparam match [MatchData] Received match.
    # 
    # @see Ionian::Extension::IO#read_match
    def cmd data, **kwargs, &block
      create_socket unless @persistent
      
      write data
      @socket.flush
      
      matches = @socket.read_match(kwargs) { |match| yield match if block_given? }
      @socket.close unless @persistent
      
      matches
    end
    
    # Register a block to be called when {Ionian::Extension::IO#run_match}
    # receives matched data.
    # Method callbacks can be registered with &object.method(:method).
    # @return [Block] The given block.
    # @yield [MatchData, self]
    def register_match_handler &block
      @ionian_match_handlers << block unless @ionian_match_handlers.include? block
      @socket.register_match_handler &block if @socket
      block
    end
    
    alias_method :on_match, :register_match_handler
    
    # @deprecated Use {#register_match_handler} instead.
    def register_observer &block
      STDOUT.puts "WARN: Call to deprecated method #{__method__}"
      register_match_handler &block
    end
    
    # Unregister a block from being called when matched data is received.
    def unregister_match_handler &block
      @ionian_match_handlers.delete_if { |o| o == block }
      @socket.unregister_match_handler &block if @socket
      block
    end
    
    # @deprecated Use {#unregister_match_handler} instead.
    def unregister_observer &block
      STDOUT.puts "WARN: Call to deprecated method #{__method__}"
      unregister_match_handler &block
    end
    
    # Register a block to be called when {Ionian::Extension::IO#run_match}
    # raises an error.
    # Method callbacks can be registered with &object.method(:method).
    # @return [Block] a reference to the given block.
    # @yield [Exception, self]
    def register_error_handler &block
      @ionian_error_handlers << block unless @ionian_error_handlers.include? block
      @socket.register_error_handler &block if @socket
      block
    end
    
    alias_method :on_error, :register_error_handler
    
    # Unregister a block from being called when a {Ionian::IO#run_match} error
    # is raised.
    def unregister_error_handler &block
      @ionian_error_handlers.delete_if { |o| o == block }
      @socket.unregister_error_handler &block if @socket
      block
    end
    
    ### Methods Forwarded To @socket ###
    
    # @return [Boolean] True if there is data in the receive buffer.
    # @option kwargs [Fixnum, nil] :timeout (0) Number of seconds to wait for
    # data until giving up. Set to nil for blocking.
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
    
    # Writes the given string to the socket.
    # @return [Fixnum] Number of bytes written.
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
        # sleep 0.01
        @socket.close
      end
      
      num_bytes
    end
    
    alias_method :<<, :write
    
    
    private
    
    # Initialize or reinitialize @socket.
    def create_socket
      @socket.close if @socket and not @socket.closed?
      
      begin
        Timeout.timeout(@connect_timeout) do
          case @protocol
          when :tcp
            @socket = ::TCPSocket.new @host, @port
            @socket.extend Ionian::Extension::Socket
            
            @socket.no_delay = @no_delay
            # Windows complains at SO_CORK, so only set it if it was specified.
            @socket.cork = @cork if @cork
            
          when :udp
            @socket = ::UDPSocket.new
            @socket.extend Ionian::Extension::Socket
            
            @socket.reuse_addr = true if
              @reuse_addr or
              @broadcast or
              Ionian::Extension::Socket.multicast? @host
              
            @socket.broadcast = true if @broadcast
            
            @socket.bind ::Socket::INADDR_ANY, @bind_port
            @socket.connect @host, @port
            
            @socket.ip_add_membership if Ionian::Extension::Socket.multicast? @host
            
          when :unix
            @socket = ::UNIXSocket.new @host
            @socket.extend Ionian::Extension::Socket
            
          end
          
          # Windows complains at SO_LINGER, so only set it if it was specified.
          @socket.linger = @linger if @linger
          
          @socket.expression = @expression if @expression
          
          # Register handlers.
          @ionian_match_handlers.each { |proc| @socket.on_match &proc }
          @ionian_error_handlers.each { |proc| @socket.on_error &proc }
          
          initialize_socket_methods
        end
      rescue Timeout::Error
        raise Errno::EHOSTUNREACH
      end
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