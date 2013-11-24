require 'listener_socket_context'
require 'ionian_interface'
require 'ionian/extension/socket'

describe Ionian::Extension::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  
  
  it "provides accessors for tcp_nodelay" do
    @ionian.should respond_to :no_delay
    @ionian.should respond_to :no_delay=
    
    @ionian.no_delay = true
    @ionian.no_delay.should eq true
    
    @ionian.no_delay = false
    @ionian.no_delay.should eq false
  end
  
end