module Ionian
  # A mixin for IO objects that allows regular expression matching
  # and convenient notification of data in the buffer.
  #
  # This module was designed to be EXTENDED by instantiated objects
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
      @ionian_listeners  = []
      @ionian_buf        = ''
      @ionian_expression = /(.*?)\n/
      @ionian_timeout    = 1
    end
   
    # Set the expression to match against the read buffer.
    # Can be a regular expression specifying capture groups,
    # or a string specifying the separator or line terminator
    # sequence. It is possible to use named captures in a
    # regex, which allows for convienient accessors like
    # match[:parameter].
    def match(expression)
      @ionian_expression = expression
      @ionian_expression = Regexp.new "(.*?)#{expression}" if expression.is_a? String
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
    # buffer for the next read_match cycle. This is helpful for protocols
    # like RS232 that do not have packet boundries.
    #
    # kvargs:
    #   Timeout: Timeout in seconds IO::select will block.
    def read_match(**kvargs, &block)
      timeout = kvargs.fetch :timeout, @ionian_timeout
      
      return nil unless IO.select [self], nil, nil, timeout
      @ionian_buf << read_partial 0xFFFF
      
      @matches = []
      
      while @ionian_buf =~ @ionian_expression
        @matches << $~ # Match data.
        yield $~
      end
      
      @ionian_buf = $' # Leave post match data in the buffer.
      @matches
   end
   
    # Start a thread that checks for data and notifies listeners.
    # Passes kvargs to #read_match.
    # This method SHOULD NOT be used if #read_match is used.
    def run_match(**kvargs)
      @match_listener ||= Thread.new do
        while not closed? do
            matches = read_match kvargs
            @ionian_listeners.each {|listener| yield matches} if matches
        end
        
        @match_listener = nil
      end
    end
   
   # Erase the data in Ionian's buffer.
    def purge
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
   
    # Unregister a block from being called when matched data is received.
    def unregister_observer(&block)
      @ionian_listeners.delete_if {|o| o == block}
      block
    end
   
  end
end
 