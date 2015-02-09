require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/extension/socket'


describe Ionian::Extension::Socket do
  
  include_context "ionian subject", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  describe "can determine if an address is in the multicast range" do
    subject { Ionian::Extension::Socket }
    
    specify { subject.should respond_to :multicast }
    specify { subject.should respond_to :multicast? }
    
    specify { subject.multicast('224.0.0.0').should eq true }
    specify { subject.multicast('239.255.255.255').should eq true }
    specify { subject.multicast('239.192.0.1').should eq true }
    specify { subject.multicast('192.168.0.1').should eq false }
    specify { subject.multicast('0.0.0.0').should eq false }
  end
  
  it "provides accessors for reuse_addr" do
    subject.reuse_addr = true
    subject.reuse_addr?.should eq true
    
    subject.reuse_addr = false
    subject.reuse_addr?.should eq false
  end
  
  it "provides accessors for ttl" do
    subject.ttl = 32
    subject.ttl?.should eq 32
    
    subject.ttl = 128
    subject.ttl?.should eq 128
  end
  
  it "provides accessors for no_delay" do
    subject.no_delay = true
    subject.no_delay?.should eq true
    
    subject.no_delay = false
    subject.no_delay?.should eq false
  end
  
  it "provides accessors for cork" do
    subject.cork = true
    subject.cork?.should eq true
    
    subject.cork = false
    subject.cork?.should eq false
    
    subject.recork
    subject.cork?.should eq true
  end
  
  describe "with UDP socket" do
    subject { UDPSocket.new.extend Ionian::Extension::Socket }
    
    it "provides accessors for ip_multicast_if" do
      subject.ip_multicast_if = '127.0.0.1'
      subject.ip_multicast_if.should eq '127.0.0.1'
      
      subject.ip_multicast_if = '0.0.0.0'
      subject.ip_multicast_if.should eq '0.0.0.0'
    end
    
    it "provides accessors for ip_multicast_ttl" do
      subject.ip_multicast_ttl = 1
      subject.ip_multicast_ttl.should eq 1
      
      subject.ip_multicast_ttl = 128
      subject.ip_multicast_ttl.should eq 128
    end
    
    it "provides accessors for ip_multicast_loop" do
      subject.ip_multicast_loop = true
      subject.ip_multicast_loop?.should eq true
      
      subject.ip_multicast_loop = false
      subject.ip_multicast_loop?.should eq false
    end
  end
  
  describe "IPv6" do
    
    specify "ipv6_add_membership" do
      expect { subject.ipv6_add_membership }.to raise_error NotImplementedError
    end
    
    specify "ipv6_drop_membership" do
      expect { subject.ipv6_drop_membership }.to raise_error NotImplementedError
    end
    
    specify "ipv6_multicast_if" do
      expect { subject.ipv6_multicast_if }.to raise_error NotImplementedError
      expect { subject.ipv6_multicast_if = nil }.to raise_error NotImplementedError
    end
    
    specify "ipv6_multicast_hops" do
      expect { subject.ipv6_multicast_hops }.to raise_error NotImplementedError
      expect { subject.ipv6_multicast_hops = nil }.to raise_error NotImplementedError
    end
    
    specify "ipv6_multicast_loop" do
      expect { subject.ipv6_multicast_loop }.to raise_error NotImplementedError
      expect { subject.ipv6_multicast_loop = nil }.to raise_error NotImplementedError
    end
    
  end
  
end
