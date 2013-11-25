require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/socket'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  before do
    @socket = @object = Ionian::Socket.new host: 'localhost', port: @port
    
    @unix_socket_file = '/tmp/ionian.test.sock'
    File.delete @unix_socket_file if File.exists? @unix_socket_file
    @unix_server = UNIXServer.new @unix_socket_file
  end
  
  after do
    @socket.close if @socket and not @socket.closed?
    @socket = @object = nil
    
    @unix_server.close if @unix_server and not @unix_server.closed?
    @unix_server = nil
    File.delete @unix_socket_file if File.exists? @unix_socket_file
  end
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  it "responds to protocol?" do
    @socket.should respond_to :protocol?
  end
  
  it "responds to persistent?" do
    @socket.should respond_to :persistent?
  end
  
  
  it "can be instantiated as a TCP client socket" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port, protocol: :tcp
    @socket.protocol?.should eq :tcp
    @socket.instance_variable_get(:@socket).class.should eq TCPSocket
  end
  
  it "can be instantiated as a UDP client socket" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port, protocol: :udp
    @socket.protocol?.should eq :udp
    @socket.instance_variable_get(:@socket).class.should eq UDPSocket
  end
  
  it "can be instantiated as a Unix client socket" do
    @socket = Ionian::Socket.new host: @unix_socket_file, protocol: :unix
    @socket.protocol?.should eq :unix
    @socket.instance_variable_get(:@socket).class.should eq UNIXSocket
  end
  
  it "defaults to TCP if the protocol is not specified" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port
    @socket.protocol?.should eq :tcp
    @socket.instance_variable_get(:@socket).class.should eq TCPSocket
  end
  
  it "defaults to persistent" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port
    @socket.persistent?.should eq true
  end
  
  it "can open a persistent TCP client (standard: stays open)" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port, protocol: :tcp
    @socket.persistent?.should eq true
    @socket.instance_variable_get(:@socket).closed?.should eq false
    
    # Send data.
    data = 'test'
    @socket.write data
    @socket.flush
    
    sleep 0.1
    @client.extend Ionian::Extension::Socket
    @client.has_data?.should eq true
    @client.readpartial(0xFFFF).should eq data
  end
  
  it "can open a persistent UDP client (standard: stays open)" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port, protocol: :udp
    @socket.persistent?.should eq true
    @socket.instance_variable_get(:@socket).closed?.should eq false
    
    # Send data.
  end
  
  it "can open a persistent Unix client (standard: stays open)" do
    @socket = Ionian::Socket.new host: @unix_socket_file, protocol: :unix
    @socket.persistent?.should eq true
    @socket.instance_variable_get(:@socket).closed?.should eq false
    
    # Send data.
  end
  
  it "can open a non-persistent TCP client (closes after message received)"
  
  it "can open a non-persistent Unix client (closes after message received)"
  
  it "igores the non-persistent flag for UDP sockets"
  
  it "can open a send-and-forget TCP client (closes after TX)"
  
  it "can open a send-and-forget Unix client (closes after TX)"
  
  it "ignores the send-and-forget flag for UDP sockets"
  
end