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
      @host           = kvargs.fetch :host
      @port           = kvargs.fetch :port, 23
      @expression     = kvargs.fetch :expression, nil
      @non_persistent = kvargs.fetch :non_persistent, false
      
      create_socket unless @non_persistent
    end
    
    private
    def create_socket(**kvargs)
      @socket.close if @socket and not @socket.closed?
      
      @socket = ::TCPSocket.new @host, @port
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
          singleton_class.send :define_method, m do |*args, &block|
            @socket.__send__ m, *args, &block
          end
        end
      
      @socket_methods_initialized = true
    end
    
    # Returns true if there is data in the receive buffer.
    def has_data?
      return false unless @socket
      @socket.has_data?
    end
    
    # Returns true if the socket is closed.
    def closed?
      return true unless @socket
      @socket.closed?
    end
    
    def write(string)
      
      ######
      # TODO
      ######
      # Should this just pass to @socket.write and non-persistent
      # gets its own set of methods?
      ######
      # For compatibility, this should probably return number of
      # bytes written.
      # 
      # If that's the case, how do you receive data from a closed
      # socket?
      # Do non-persistent sockets always have to use read_match?
      # Is #readpartial called after write?
      # What if no data is expected to come back? Does that fall
      # under :no_receive (symbol not determined)?
      # Does the received data get dumped in @buf and accessed
      # through overridden methods of the IO readers?
      # 
      # ** Do the minimum to keep the function compatible. **
      
      
      create_socket if @non_persistent
      num_bytes = @socket.write
      
      if @non_persistent
        # Read in data to prevent RST packets.
        has_data = ::IO.select [@socket], nil, nil, 0
        @socket.readpartial 0xFFFF if has_data
        
        @socket.close
      end
      
      num_bytes
    end
    
  end
end