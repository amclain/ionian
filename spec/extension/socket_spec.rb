require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/extension/socket'


describe Ionian::Extension::Socket do
  
  include_context "ionian subject", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  it "provides accessors for tcp_nodelay" do
    subject.should respond_to :no_delay
    subject.should respond_to :no_delay=
    
    subject.no_delay = true
    subject.no_delay.should eq true
    
    subject.no_delay = false
    subject.no_delay.should eq false
  end
  
end