require 'ionian/extension/io'
require 'socket'

module Ionian
  module Extension
    # A mixin for Socket objects.
    # 
    # This module was designed to be extended by instantiated objects
    # that implement the standard library Socket class.
    # my_socket.extend Ionian::Socket
    # 
    # Extending this module also extends Ionian::IO.
    module Socket
      
      # Called automaticallly when the object is extended with #extend.
      def self.extended(obj)
        obj.extend Ionian::Extension::IO
        obj.initialize_ionian_socket
      end
      
      def initialize_ionian_socket
      end
      
      # Returns true if the TCP_NODELAY flag is enabled (Nagle disabled).
      # Otherwise false.
      def no_delay
        nagle_disabled = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY).data.ord
        nagle_disabled > 0 ? true : false
      end
      
      # Setting to true enables the TCP_NODELAY flag (disables Nagle).
      # Setting to false disables the flag (enables Nagle).
      def no_delay=(value)
        disable_nagle = value ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, disable_nagle
      end
      
    end
  end
end