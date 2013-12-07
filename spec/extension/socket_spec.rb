require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/extension/socket'


describe Ionian::Extension::Socket do
  
  include_context "ionian subject", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
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
  
end