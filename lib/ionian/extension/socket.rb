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
      
      # Returns true if local address reuse is allowed.
      # ( SO_REUSEADDR )
      def reuse_addr
        param = self.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR).data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :reuse_addr?, :reuse_addr
      
      # Allows local address reuse if true.
      # ( SO_REUSEADDR )
      def reuse_addr=(value)
        param = value ? 1 : 0
        self.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, [param].pack('i')
      end
      
      # Returns the time to live (hop limit).
      # ( IP_TTL )
      def ttl
        self.getsockopt(::Socket::IPPROTO_IP, ::Socket::IP_TTL).data.unpack('i').first
      end
      
      alias_method :ttl?, :ttl
      
      # Sets the time to live (hop limit).
      # ( IP_TTL )
      def ttl=(value)
        self.setsockopt ::Socket::IPPROTO_IP, ::Socket::IP_TTL, [value].pack('i')
      end
      
      # Returns true if the Nagle algorithm is disabled.
      # ( TCP_NODELAY )
      def no_delay
        param = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY).data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :no_delay?, :no_delay
      
      # Disables the Nagle algorithm if true.
      # ( TCP_NODELAY )
      def no_delay=(value)
        param = value ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, [param].pack('i')
      end
      
      # Returns true if multiple writes are buffered into a single segment.
      # Linux only.
      # ( TCP_CORK )
      def cork
        param = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_CORK).data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :cork?, :cork
      
      # Buffers multiple writes into a single segment if true.
      # The segment is sent once the cork flag is disabled,
      # the upper limit on the size of a segment is reached,
      # the socket is closed, or 200ms elapses from the time
      # the first corked byte is written.
      # Linux only.
      # ( TCP_CORK )
      def cork=(value)
        param = value ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_CORK, [param].pack('i')
      end
      
     def ip_add_membership
        # TODO: Implement
        false
      end
      
      def ip_drop_membership
        # TODO: Implement
        false
      end
      
      def ip_multicast_if
        # TODO: Implement
        false
      end
      
      alias_method :ip_multicast_if?, :ip_multicast_if
      
      def ip_multicast_if=(value)
        # TODO: Implement
      end
      
      def ip_multicast_ttl
        # TODO: Implement
        false
      end
      
      alias_method :ip_multicast_ttl?, :ip_multicast_ttl
      
      def ip_multicast_ttl=(value)
        # TODO: Implement
      end
      
      def ip_multicast_loop
        # TODO: Implement
        false
      end
      
      alias_method :ip_multicast_loop?, :ip_multicast_loop
      
      def ip_multicast_loop=(value)
        # TODO: Implement
      end
      
      def ipv6_add_membership
        # TODO: Implement
        false
      end
      
      def ipv6_drop_membership
        # TODO: Implement
        false
      end
      
      def ipv6_multicast_if
        # TODO: Implement
        false
      end
      
      alias_method :ipv6_multicast_if?, :ipv6_multicast_if
      
      def ipv6_multicast_if=(value)
        # TODO: Implement
      end
      
      def ipv6_multicast_hops
        # TODO: Implement
        false
      end
      
      alias_method :ipv6_multicast_hops?, :ipv6_multicast_hops
      
      def ipv6_multicast_hops=(value)
        # TODO: Implement
      end
      
      def ipv6_multicast_loop
        # TODO: Implement
        false
      end
      
      alias_method :ipv6_multicast_loop?, :ipv6_multicast_loop
      
      def ipv6_multicast_loop=(value)
        # TODO: Implement
      end
      
      
      
      
      
      def multicast
        # TODO: Implement.
        false
      end
      
      alias_method :multicast?, :multicast
      
      def multicast=(value)
        # TODO: params for IPv6 are different.
        
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