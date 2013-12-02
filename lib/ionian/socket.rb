require 'ionian/extension/socket'

module Ionian
  class Socket
    
    ############
    # TODO NOTES
    ############
    # Always lazily instiantiate @socket, even when persistent?
    # May not work with forwarding method calls.
    # Oh! Unless the forwarded methods check for @socket to exist.
    # Will persistent methods have to check for the socket not to be
    # closed as well?
    
    def initialize(**kvargs)
      @socket         = nil
      
      @host           = kvargs.fetch :host
      @port           = kvargs.fetch :port, 23
      @expression     = kvargs.fetch :expression, nil
      @protocol       = kvargs.fetch :protocol, :tcp
      @persistent     = kvargs.fetch :persistent, true
      
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
    
    # Send a command (data) to the socket. Returns received matches.
    # Block yields received match.
    # See Ionian::Extension::IO#read_match
    def cmd(string, **kvargs, &block)
      create_socket unless @persistent
      @socket.write string
      @socket.flush
      
      matches = @socket.read_match(kvargs) {|match| yield match if block_given?}
      @socket.close unless @persistent
      
      matches
    end
    
    
    ### Methods Forwarded To @socket ###
    
    # Returns true if there is data in the receive buffer.
    # Args:
    #   Timeout: Number of seconds to wait for data until
    #     giving up. Set to nil for blocking.
    def has_data?(**kvargs)
      return false unless @socket
      @socket.has_data? kvargs
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
      num_bytes = @socket.write string
      
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
    
    def create_socket
      @socket.close if @socket and not @socket.closed?
      
      case @protocol
      when :tcp
        @socket = ::TCPSocket.new @host, @port
      when :udp
        @socket = ::UDPSocket.new
        @socket.connect @host, @port
      when :unix
        @socket = ::UNIXSocket.new @host
      end
      
      @socket.extend Ionian::Extension::Socket
      @socket.expression = @expression if @expression
      
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