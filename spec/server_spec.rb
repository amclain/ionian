require 'ionian/server'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

describe Ionian::Server do
  
  let (:kwargs) {{ port: 5051 }}
  
  subject { Ionian::Server.new **kwargs }
  
  after { subject.close }
  
  
  it { should respond_to :listen }
  it { should respond_to :close }
  
  
  describe "accept listener registration" do
    it { should respond_to :on_accept }
    it { should respond_to :register_accept_listener }
    it { should respond_to :unregister_accept_listener }
    
    it "can register in initialization block" do
      client = nil
      
      server = Ionian::Server.new **kwargs do |c|
        client = c
      end
      
      server.listen
      
      # Create client connection.
      remote_client = TCPSocket.new 'localhost', kwargs[:port]
      sleep 0.1
      
      remote_client.close
      server.close
      
      # It returns an Ionian socket when a connection is accepted.
      client.should be_an Ionian::Socket
    end
    
    it "can register an accept listener" do
      client = nil
      
      server = Ionian::Server.new **kwargs
      
      server.register_accept_listener do |c|
        client = c
      end
      
      server.listen
      
      # Create client connection.
      remote_client = TCPSocket.new 'localhost', kwargs[:port]
      sleep 0.1
      
      remote_client.close
      server.close
      
      client.should be_an Ionian::Socket
    end
    
    it "can unregister an accept listener" do
      client = nil
      
      server = Ionian::Server.new **kwargs
      
      handler = server.register_accept_listener do |c|
        client = c
      end
      
      handler.should be_a Proc
      
      server.unregister_accept_listener handler
      
      server.listen
      
      # Create client connection.
      remote_client = TCPSocket.new 'localhost', kwargs[:port]
      sleep 0.1
      
      remote_client.close
      server.close
      
      client.should be nil
    end
    
  end
  
  
  describe "with protocol: :tcp" do
    
  end
  
  
  describe "with protocol: :udp" do
    # TODO: UDP sockets use datagrams, not the client/server model.
  end
  
  
  describe "with protocol: :unix" do
    
    let (:socket_file) { '/tmp/ionian.server.test.sock' }
    let (:kwargs) {{ interface: socket_file }}
    
    before { File.delete socket_file if File.exists? socket_file }
    after { File.delete socket_file if File.exists? socket_file }
    
    it "can wrap an existing Unix socket" do
      client = nil
      
      server = Ionian::Server.new **kwargs do |c|
        client = c
      end
      
      server.listen
      
      # Create client connection.
      remote_client = UNIXSocket.new socket_file
      sleep 0.1
      
      remote_client.close
      server.close
      
      # It returns an Ionian socket when a connection is accepted.
      client.should be_an Ionian::Socket
    end
    
  end
  
end
