Thread.abort_on_exception = true

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
      def self.extended obj
        obj.initialize_ionian
      end
      
      # Initialize the Ionian instance variables.
      # This is called automatically if #extend is called on an object.
      def initialize_ionian
        @ionian_match_handlers = []
        @ionian_error_handlers = []
        @ionian_buf            = ''
        @ionian_expression     = /(.*?)[\r\n]+/
        @ionian_timeout        = nil
        @ionian_skip_select    = false
        @ionian_build_methods  = true
      end
      
      # @return [Boolean] True if there is data in the receive buffer.
      # 
      # @param timeout [Numeric] Number of seconds to wait for data until
      #   giving up. Set to nil for blocking.
      # 
      def has_data? timeout: 0
        ::IO.select([self], nil, nil, timeout) ? true : false
      end
      
      # Returns the regular expression used for {#read_match}.
      def expression
        @ionian_expression
      end
      
      # Set the expression to match against the read buffer.
      # Can be a regular expression specifying capture groups,
      # or a string specifying the separator or line terminator
      # sequence. It is possible to use named captures in a
      # regex, which allows for convienient accessors like
      # match[:parameter].
      def expression= exp
        @ionian_expression = exp
        @ionian_expression = Regexp.new "(.*?)#{expression}" if exp.is_a? String
      end
      
      # Read all data in the buffer.
      # An alternative to using #readpartial with a large length.
      # Blocks until data is available unless nonblocking: true.
      # If nonblocking, returns nil if no data available.
      def read_all nonblocking: false
        return nil if nonblocking and not has_data?
        
        # Block until data has arrived.
        data =  readpartial 0xFFFF
        # If there is more data in the buffer, retrieve it nonblocking.
        data += readpartial 0xFFFF while has_data?
        data
      end
      
      # Read matched data from the buffer.
      # This method SHOULD NOT be used if {#run_match} is used.
      # 
      # Junk data that could exist before a match in the buffer can
      # be accessed with match.pre_match.
      # 
      # Data at the end of the buffer that is not matched can be accessed
      # in the last match with match.post_match. This data remains in the
      # buffer for the next {#read_match} cycle. This is helpful for protocols
      # like RS232 that do not have packet boundries.
      # 
      # 
      # @yieldparam match [MatchData] If there are multiple matches, the block
      #   is called multiple times.
      # 
      # @return [Array<MatchData>, nil] Returns an array of matches.
      #   Returns nil if no data was received within the timeout period.
      # 
      # 
      # @option kwargs [Numeric] :timeout (nil) Timeout in seconds IO::select
      #   will block. Blocks indefinitely by default. Set to 0 for nonblocking.
      # 
      # @option kwargs [Regexp, String] :expression Override the expression
      #   match for this single method call.
      # 
      # @option kwargs [Boolean] :notify (true) Set to false to skip notifying
      #   match handler procs.
      # 
      # @option kwargs [Boolean] :skip_select (false) Skip over the
      #   IO::select statement. Use if you are calling IO::select ahead of
      #   this method.
      # 
      # @option kwargs [Boolean] :build_methods (true) Build accessor methods
      #   from named capture groups.
      # 
      def read_match **kwargs, &block
        timeout       = kwargs.fetch :timeout,        @ionian_timeout
        notify        = kwargs.fetch :notify,         true
        skip_select   = kwargs.fetch :skip_select,    @ionian_skip_select
        build_methods = kwargs.fetch :build_methods,  @ionian_build_methods
        
        exp           = kwargs.fetch :expression,     @ionian_expression
        exp           = Regexp.new "(.*?)#{exp}" if exp.is_a? String
        
        unless skip_select
          return nil unless self.has_data? timeout: timeout
        end
        
        @matches = []
        
        # TODO: Implement an option for number of bytes or timeout to throw away
        #       data if no match is found.
        Timeout.timeout(timeout) do
          loop do
            # Read data from the IO buffer until it's empty.
            @ionian_buf << read_all
            break if @ionian_buf =~ exp
          end
        end
        
        while @ionian_buf =~ exp
          @matches << $~   # Match data.
          @ionian_buf = $' # Leave post match data in the buffer.
        end
        
        # Convert named captures to methods.
        if build_methods
          @matches.each do |match|
            match.names
              .map { |name| name.to_sym }
              .each { |symbol|
                match.singleton_class
                  .send(:define_method, symbol) { match[symbol] } \
                    unless match.respond_to? symbol
              }
          end
        end
        
        # Pass each match to block.
        @matches.each { |match| yield match } if block_given?
        
        # Notify on_match handlers unless the #run_match thread is active.
        @matches.each { |match| notify_match_handlers match } \
          if notify and not @run_match_thread
        
        @matches
      end
     
      # Start a thread that checks for data and notifies match and error handlers.
      # Passes kwargs to {#read_match}.
      # This method SHOULD NOT be used if {#read_match} is used.
      def run_match **kwargs
        @run_match_thread ||= Thread.new do
          begin
            while not closed? do
              matches = read_match **kwargs
              matches.each { |match| notify_match_handlers match } if matches
            end
          rescue Exception => e
            notify_error_handlers e
          ensure
            @run_match_thread = nil
          end
        end
      end
      
      # Erase the data in the IO and Ionian buffers.
      # This is typically handled automatically.
      def purge
        # Erase IO buffer.
        read_all
        @ionian_buf = ''
      end
      
      # Register a block to be called when {#run_match} receives matched data.
      # Method callbacks can be registered with &object.method(:method).
      # @return [Block] a reference to the given block.
      # @yield [MatchData, self] Regex match.
      # 
      # @example
      #   registered_block = ionian_socket.register_match_handler { |match| ... }
      # 
      # @example
      #   registered_block = ionian_socket.register_match_handler &my_object.method(:foo)
      def register_match_handler &block
        @ionian_match_handlers << block unless @ionian_match_handlers.include? block
        block
      end
      
      alias_method :on_match, :register_match_handler
      
      # @deprecated Use {#register_match_handler} instead.
      def register_observer &block
        register_match_handler &block
      end
      
      # Unregister a block from being called when matched data is received.
      def unregister_match_handler &block
        @ionian_match_handlers.delete_if { |o| o == block }
        block
      end
      
      # @deprecated Use {#unregister_match_handler} instead.
      def unregister_observer &block
        unregister_match_handler &block
      end
      
      # Register a block to be called when {#run_match} raises an error.
      # Method callbacks can be registered with &object.method(:method).
      # @return [Block] a reference to the given block.
      # @yield [Exception, self]
      def register_error_handler &block
        @ionian_error_handlers << block unless @ionian_error_handlers.include? block
        block
      end
      
      alias_method :on_error, :register_error_handler
      
      # Unregister a block from being called when a {#run_match} error is raised.
      def unregister_error_handler &block
        @ionian_error_handlers.delete_if { |o| o == block }
        block
      end
      
      
      private
      
      # Send match to each of the registered observers. Includes self
      # as the second block parameter.
      def notify_match_handlers match
        @ionian_match_handlers.each { |handler| handler.call match, self }
      end
      
      # Send exception to each of the registered observers. Includes self
      # as the second block parameter.
      def notify_error_handlers exception
        @ionian_error_handlers.each { |handler| handler.call exception, self }
      end
    
    end
  end
end