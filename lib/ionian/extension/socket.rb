require 'ionian/extension/io'
require 'socket'
require 'ipaddr'

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
      
      # Initialize the Ionian Socket variables.
      # This is called automatically if #extend is called on an object.
      def initialize_ionian_socket
      end
      
      # Returns true if the TCP_NODELAY flag is enabled (Nagle disabled).
      # Otherwise false.
      def no_delay
        nagle_disabled = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY).data.ord
        nagle_disabled > 0 ? true : false
      end
      
      alias_method :no_delay?, :no_delay
      
      # Setting to true enables the TCP_NODELAY flag (disables Nagle).
      # Setting to false disables the flag (enables Nagle).
      def no_delay=(value)
        disable_nagle = value ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, disable_nagle
      end
      
      def multicast
        # TODO: Implement.
        false
      end
      
      alias_method :multicast?, :multicast
      
      def multicast=(value)
        # TODO: Flags for IPv6 are different.
        
        if value == true
          # TODO: Set appropriate scope value.
          #       See "Unix Network Programming", p.490
          self.setsockopt ::Socket::IPPROTO_IP, ::Socket::IP_TTL, [1].pack('i')
          
          # TODO: See "Unix Network Programming", p.496
          self.setsockopt \
            ::Socket::IPPROTO_IP,
            ::Socket::IP_ADD_MEMBERSHIP,
            IPAddr.new(self.remote_address.ip_address).hton + IPAddr.new('0.0.0.0').hton
          
          # TODO: This option needs to happen before the socket is bound.
          #       It's also useful on TCP sockets, especially on a server.
          #       See "The Linux Programming Interface", p.1280
          self.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, [1].pack('i')
        else
          # TODO: Implement disabling multicast.
        end
      end
      
    end
  end
end