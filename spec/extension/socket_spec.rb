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
  end
  
end