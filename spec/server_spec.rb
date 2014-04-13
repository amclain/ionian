require 'ionian/server'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

shared_examples "send and receive data" do
  it do
    data = "test data\n"
    client
    connection = connections.first
    
    connection.write data
    connection.flush
    sleep 0.1
    
    client.read_all.should eq data
    
    data = "more test data\n"
    client.write data
    client.flush
    sleep 0.1
    
    connection.read_all.should eq data
  end
end


describe Ionian::Server do
  
  let(:port) { 5051 }
  let(:protocol) { :tcp }
  let(:kwargs) {{ port: port, protocol: protocol }}
  
  let(:connections) { [] }
  let(:server) {
    Ionian::Server.new(**kwargs) { |con| connections << con }
  }
  
  subject { server }
  
  after {
    server.close
    connections.each { |con| con.close unless con.closed? }
  }
  
  
  it { should respond_to :interface }
  it { should respond_to :port }
  it { should respond_to :protocol }
  
  it { should respond_to :listen }
  it { should respond_to :close }
  it { should respond_to :closed? }
  
  
  describe "accept listener registration" do
    
    let(:remote_client) { TCPSocket.new 'localhost', kwargs[:port] }
    
    it { should respond_to :on_accept }
    it { should respond_to :register_accept_listener }
    it { should respond_to :unregister_accept_listener }
    
    it "can register in #initialize block" do
      client = nil
      
      server = Ionian::Server.new(**kwargs) { |con| client = con }
      
      # Create client connection.
      remote_client
      sleep 0.1
      
      # It returns an Ionian socket when a connection is accepted.
      client.should be_an Ionian::Socket
      
      remote_client.close
      server.close
    end
    
    it "can register in #listen block" do
      client = nil
      
      server = Ionian::Server.new(**kwargs)
      server.listen { |c| client = c }
      
      # Create client connection.
      remote_client
      sleep 0.1
      
      # It returns an Ionian socket when a connection is accepted.
      client.should be_an Ionian::Socket
      
      remote_client.close
      server.close
    end
    
    it "can register an accept listener" do
      client = nil
      
      server = Ionian::Server.new **kwargs
      
      server.register_accept_listener do |c|
        client = c
      end
      
      server.listen
      
      # Create client connection.
      remote_client
      sleep 0.1
      
      client.should be_an Ionian::Socket
      
      remote_client.close
      server.close
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
      remote_client
      sleep 0.1
      
      client.should be nil
      
      remote_client.close
      server.close
    end
    
    it "can accept multiple clients" do
      clients = []
      num_connections = 5
      
      server = Ionian::Server.new(**kwargs) { |con| clients << con }
      
      # Create client connections.
      num_connections.times do
        sock = Ionian::Socket.new host: 'localhost', port: port, protocol: protocol
        sleep 0.1
        sock.close
      end
      
      server.close
      
      # It returns an Ionian socket when a connection is accepted.
      clients.count.should eq num_connections
    end
    
  end
  
  
  describe "with protocol :tcp" do
    
    let(:client) {
      server
      TCPSocket.new('localhost', port).tap do |socket|
        socket.extend Ionian::Extension::IO
        socket.extend Ionian::Extension::Socket
        socket.reuse_addr = true
        sleep 0.1 # Yield so server can accept connection.
      end
    }
    
    after { client.close unless client.closed? }
    
    
    its(:interface) { should eq '0.0.0.0' }
    its(:port)      { should eq port }
    its(:protocol)  { should eq :tcp }
    
    it "requires port to be specified" do
      expect { Ionian::Server.new }.to raise_error ArgumentError
    end
    
    it "accepts a listener" do
      client # Instantiate the client and server.
      connections.count.should eq 1
    end
    
    include_examples "send and receive data"
    
    
    it "can parse port from interface string" do
      port = 5060
      host = 'localhost'
      interface = "#{host}:#{port}"
      
      s = Ionian::Server.new interface: interface
      
      s.interface.should eq host
      s.port.should eq port
      
      s.close
    end
    
  end
  
  
  describe "with protocol :udp" do
    
    # UDP sockets use datagrams, not the client/server model,
    # therefore Ionian::Server should not implement them.
    specify {
      expect { Ionian::Server.new port: port, protocol: :udp }
        .to raise_error ArgumentError
    }
    
  end
  
  
  describe "with protocol :unix" do
    
    let(:socket_file) { '/tmp/ionian.server.test.sock' }
    let(:kwargs) {{ interface: socket_file }}
    
    let(:client) {
      server
      UNIXSocket.new(socket_file).tap do |socket|
        socket.extend Ionian::Extension::IO
        socket.extend Ionian::Extension::Socket
        sleep 0.1 # Yield so server can accept connection.
      end
    }
    
    before { File.delete socket_file if File.exists? socket_file }
    
    after  {
      client.close unless client.closed?
      File.delete socket_file if File.exists? socket_file
    }
    
    
    its(:interface) { should eq socket_file }
    its(:port)      { should eq nil }
    its(:protocol)  { should eq :unix }
    
    it "should raise error if path not specified" do
      expect { Ionian::Server.new protocol: :unix }.to raise_error ArgumentError
    end
    
    include_examples "send and receive data"
  end
  
end
