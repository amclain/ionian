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
      def self.extended obj
        obj.extend Ionian::Extension::IO
        obj.initialize_ionian_socket
      end
      
      # Initialize the Ionian Socket variables.
      # This is called automatically if #extend is called on an object.
      def initialize_ionian_socket
      end
      
      # Returns true if sending broadcast datagrams is permitted.
      # ( SO_BROADCAST )
      def broadcast
        param = self.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_BROADCAST)
          .data.unpack('i').first
        param > 0 ? true : false
      end
      
      # Permit sending broadcast datagrams if true.
      # ( SO_BROADCAST )
      def broadcast= value
        param = (!!value && value != 0) ? 1 : 0
        self.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_BROADCAST, [param].pack('i')
      end
      
      alias_method :broadcast?, :broadcast
      
      # For connection-oriented protocols, prevent #close from returning
      # immediately and try to deliver any data in the send buffer if value
      # is true.
      # ( SO_LINGER )
      def linger
        param = self.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_LINGER)
          .data.unpack('i').first
        param > 0 ? true : false
      end
      
      # For connection-oriented protocols, prevent #close from returning
      # immediately and try to deliver any data in the send buffer if value
      # is true.
      # 
      # Args:
      #   Time: Time in seconds to remain open before discarding data and
      #         sending a RST packet.
      # ( SO_LINGER )
      def linger= enable, time: 60
        # TODO: Passing a kwarg doesn't work here because of the
        #       assignment operator. Causes parser error.
        param = (!!enable && enable != 0) ? 1 : 0
        self.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_LINGER, [param, time.to_i].pack('ii')
      end
      
      alias_method :linger?, :linger
      
      # Returns true if local address reuse is allowed.
      # ( SO_REUSEADDR )
      def reuse_addr
        param = self.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR)
          .data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :reuse_addr?, :reuse_addr
      
      # Allows local address reuse if true.
      # ( SO_REUSEADDR )
      def reuse_addr= value
        param = (!!value && value != 0) ? 1 : 0
        self.setsockopt ::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, [param].pack('i')
      end
      
      # Returns the time to live (hop limit).
      # ( IP_TTL )
      def ttl
        self.getsockopt(::Socket::IPPROTO_IP, ::Socket::IP_TTL)
          .data.unpack('i').first
      end
      
      alias_method :ttl?, :ttl
      
      # Sets the time to live (hop limit).
      # ( IP_TTL )
      def ttl= value
        self.setsockopt ::Socket::IPPROTO_IP, ::Socket::IP_TTL, [value].pack('i')
      end
      
      # Returns true if the Nagle algorithm is disabled.
      # ( TCP_NODELAY )
      def no_delay
        param = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY)
          .data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :no_delay?, :no_delay
      
      # Disables the Nagle algorithm if true.
      # ( TCP_NODELAY )
      def no_delay= value
        param = (!!value && value != 0) ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, [param].pack('i')
      end
      
      # Returns true if multiple writes are buffered into a single segment.
      # See #recork.
      # Linux only.
      # ( TCP_CORK )
      def cork
        param = self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_CORK)
          .data.unpack('i').first
        param > 0 ? true : false
      end
      
      alias_method :cork?, :cork
      
      # Buffers multiple writes into a single segment if true.
      # The segment is sent once the cork flag is disabled,
      # the upper limit on the size of a segment is reached,
      # the socket is closed, or 200ms elapses from the time
      # the first corked byte is written.
      # See #recork.
      # Linux only.
      # ( TCP_CORK )
      def cork= value
        param = (!!value && value != 0) ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_CORK, [param].pack('i')
      end
      
      # Unsets cork to transmit data, then reapplies cork.
      # ( TCP_CORK )
      def recork
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_CORK, [0].pack('i')
        self.setsockopt ::Socket::IPPROTO_TCP, ::Socket::TCP_CORK, [1].pack('i')
      end
      
      # Join a multicast group.
      # Address is the class D multicast address (uses remote
      # address if not specified). 
      # Interface is the local network interface to receive the
      # multicast traffic on (all interfaces if not specified).
      # ( IP_ADD_MEMBERSHIP )
     def ip_add_membership address = nil, interface = nil
        address   ||= self.remote_address.ip_address
        interface ||= '0.0.0.0'
        
        self.setsockopt \
            ::Socket::IPPROTO_IP,
            ::Socket::IP_ADD_MEMBERSHIP,
            IPAddr.new(address).hton + IPAddr.new(interface).hton
      end
      
      # Leave a multicast group.
      # Address is the class D multicast address (uses remote
      # address if not specified). 
      # Interface is the local network interface the multicast
      # traffic is received on (all interfaces if not specified).
      # ( IP_DROP_MEMBERSHIP )
      def ip_drop_membership address = nil, interface = nil
        address   ||= self.remote_address.ip_address
        interface ||= '0.0.0.0'
        
        self.setsockopt \
            ::Socket::IPPROTO_IP,
            ::Socket::IP_DROP_MEMBERSHIP,
            IPAddr.new(address).hton + IPAddr.new(interface).hton
      end
      
      # Returns the default interface for outgoing multicasts.
      # ( IP_MULTICAST_IF )
      def ip_multicast_if
        self.getsockopt(::Socket::IPPROTO_IP, ::Socket::IP_MULTICAST_IF)
          .data.unpack('CCCC').join('.')
      end
      
      # Specify default interface for outgoing multicasts.
      # ( IP_MULTICAST_IF )
      def ip_multicast_if= interface = nil
        interface ||= '0.0.0.0'
        
        self.setsockopt \
          ::Socket::IPPROTO_IP,
          ::Socket::IP_MULTICAST_IF,
          IPAddr.new(interface).hton
      end
      
      # Returns the time to live (hop limit) for outgoing multicasts.
      # ( IP_MULTICAST_TTL )
      def ip_multicast_ttl
        self.getsockopt(::Socket::IPPROTO_IP, ::Socket::IP_MULTICAST_TTL)
          .data.unpack('C').first
      end
      
      # Set the time to live (hop limit) for outgoing multicasts.
      # ( IP_MULTICAST_TTL )
      def ip_multicast_ttl= value
        self.setsockopt ::Socket::IPPROTO_IP, ::Socket::IP_MULTICAST_TTL, [value].pack('C')
      end
      
      # Returns true if loopback of outgoing multicasts is enabled.
      # ( IP_MULTICAST_LOOP )
      def ip_multicast_loop
        param = self.getsockopt(::Socket::IPPROTO_IP, ::Socket::IP_MULTICAST_LOOP)
          .data.unpack('C').first
        param > 0 ? true : false
      end
      
      alias_method :ip_multicast_loop?, :ip_multicast_loop
      
      # Enables loopback of outgoing multicasts if true.
      # ( IP_MULTICAST_LOOP )
      def ip_multicast_loop= value
        param = (!!value && value != 0) ? 1 : 0
        self.setsockopt ::Socket::IPPROTO_IP, ::Socket::IP_MULTICAST_LOOP, [param].pack('C')
      end
      
      # Not yet implemented.
      def ipv6_add_membership
        # TODO: Implement
        false
      end
      
      # Not yet implemented.
      def ipv6_drop_membership
        # TODO: Implement
        false
      end
      
      # Not yet implemented.
      def ipv6_multicast_if
        # TODO: Implement
        false
      end
      
      # Not yet implemented.
      def ipv6_multicast_if= value
        # TODO: Implement
      end
      
      # Not yet implemented.
      def ipv6_multicast_hops
        # TODO: Implement
        false
      end
      
      # Not yet implemented.
      def ipv6_multicast_hops= value
        # TODO: Implement
      end
      
      # Not yet implemented.
      def ipv6_multicast_loop
        # TODO: Implement
        false
      end
      
      alias_method :ipv6_multicast_loop?, :ipv6_multicast_loop
      
      # Not yet implemented.
      def ipv6_multicast_loop= value
        # TODO: Implement
      end
      
      
      class << self
        # Returns true if the given address is within the multicast range.
        def multicast address
          address >= '224.0.0.0' and address <= '239.255.255.255' ? true : false
        end
        
        alias_method :multicast?, :multicast
      end
      
      # Returns true if the socket's address is in the multicast range.
      def multicast
        Ionian::Extension::Socket.multicast self.remote_address.ip_address
      end
      
      alias_method :multicast?, :multicast
      
    end
  end
end