module Ionian
  module Extension
    # A mixin for IO objects that allows regular expression matching
    # and convenient notification of received data.
    #
    # This module was designed to be extended by instantiated objects
    # that implement the standard library IO class.
    # my_socket.extend Ionian::IO
    module IO
      # Number of seconds to attempt an IO operation before timing out.
      # See standard library IO::select.
      attr_accessor :ionian_timeout
      
      # Called automaticallly when the object is extended with #extend.
      def self.extended(obj)
        obj.initialize_ionian
      end
      
      # Initialize the Ionian instance variables.
      # This is called automatically if #extend is called on an object.
      def initialize_ionian
        @ionian_listeners     = []
        @ionian_buf           = ''
        @ionian_expression    = /(.*?)\n/
        @ionian_timeout       = nil
        @ionian_skip_select   = false
        @ionian_build_methods = true
      end
      
      # Returns true if there is data in the receive buffer.
      # Args:
      #   Timeout: Number of seconds to wait for data until
      #     giving up. Set to nil for blocking.
      def has_data?(timeout: 0)
        ::IO.select([self], nil, nil, timeout) ? true : false
      end
      
      # Returns the regular expression used for #read_match.
      def expression
        @ionian_expression
      end
      
      # Set the expression to match against the read buffer.
      # Can be a regular expression specifying capture groups,
      # or a string specifying the separator or line terminator
      # sequence. It is possible to use named captures in a
      # regex, which allows for convienient accessors like
      # match[:parameter].
      def expression=(exp)
        @ionian_expression = exp
        @ionian_expression = Regexp.new "(.*?)#{expression}" if exp.is_a? String
      end
      
      # Read matched data from the buffer.
      # This method SHOULD NOT be used if #run_match is used.
      #
      # Passes matches to the block (do |match|). If there are multiple
      # matches, the block is called multiple times.
      #
      # Returns an array of matches.
      # Returns nil if no data was received within the timeout period.
      #
      # Junk data that could exist before a match in the buffer can
      # be accessed with match.pre_match.
      #
      # Data at the end of the buffer that is not matched can be accessed
      # in the last match with match.post_match. This data remains in the
      # buffer for the next #read_match cycle. This is helpful for protocols
      # like RS232 that do not have packet boundries.
      #
      # kvargs:
      #   timeout:        Timeout in seconds IO::select will block.
      #   skip_select:    Skip over the IO::select statement. Use if you
      #                   are calling IO::select ahead of this method.
      #   build_methods:  Build method accessors from named captures.
      #                   Enabled by default.
      def read_match(**kvargs, &block)
        timeout       = kvargs.fetch :timeout, @ionian_timeout
        skip_select   = kvargs.fetch :skip_select, @ionian_skip_select
        build_methods = kvargs.fetch :build_methods, @ionian_build_methods
        
        unless skip_select
          return nil unless ::IO.select [self], nil, nil, timeout
        end
        
        # Read data from the IO buffer until it's empty.
        loop do
          @ionian_buf << readpartial(0xFFFF)
          break unless ::IO.select [self], nil, nil, 0
        end
        
        @matches = []
        
        while @ionian_buf =~ @ionian_expression
          @matches << $~ # Match data.
          yield $~ if block_given?
          @ionian_buf = $' # Leave post match data in the buffer.
        end
        
        # Convert named captures to methods.
        if build_methods
          @matches.each do |match|
            match.names
              .map {|name| name.to_sym}
              .each {|symbol| match.singleton_class
                .send(:define_method, symbol) { match[symbol] } \
                  unless match.respond_to? symbol
              }
          end
        end
        
        @matches
      end
     
      # Start a thread that checks for data and notifies listeners (do |match, socket|).
      # Passes kvargs to #read_match.
      # This method SHOULD NOT be used if #read_match is used.
      def run_match(**kvargs)
        @match_listener ||= Thread.new do
          begin
            while not closed? do
                matches = read_match kvargs
                matches.each {|match|
                  @ionian_listeners.each {|listener| listener.call match, self}
                } if matches
            end
          rescue EOFError
          rescue IOError
          ensure
            @match_listener = nil
          end
        end
      end
      
      # Erase the data in the IO and Ionian buffers.
      # This is typically handled automatically.
      def purge
        # Erase IO buffer.
        while ::IO.select [self], nil, nil, 0
          readpartial(0xFFFF)
        end
        
        @ionian_buf = ''
      end
      
      # Register a block to be called when #run_match receives matched data.
      # Method callbacks can be registered with &object.method(:method).
      # Returns a reference to the given block.
      # block = ionian_socket.register_observer {...}
      def register_observer(&block)
        @ionian_listeners << block unless @ionian_listeners.include? block
        block
      end
      
      alias_method :on_match, :register_observer
      
      # Unregister a block from being called when matched data is received.
      def unregister_observer(&block)
        @ionian_listeners.delete_if {|o| o == block}
        block
      end
    
    end
  end
end