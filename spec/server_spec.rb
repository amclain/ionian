require 'ionian/server'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

describe Ionian::Server do
  
  it { should respond_to :listen }
  it { should respond_to :close }
  
  
  describe "accept listener registration" do
    it { should respond_to :on_accept }
    it { should respond_to :register_accept_listener }
    it { should respond_to :unregister_accept_listener }
    
    it "can register in initialization block" do
      client = nil
      
      server = Ionian::Server.new do |c|
        client = c
      end
      
      server.listen
      server.close
      
      client.should be_an Ionian::Socket
    end
    
    it "can register an accept listener"
    
    it "can unregister an accept listener"
    
  end
  
  
  describe "with protocol: :tcp" do
    
    it "returns an Ionian socket when a connection is accepted"
    
  end
  
  
  describe "with protocol: :udp" do
  end
  
  
  describe "with protocol: :unix" do
  end
  
end
