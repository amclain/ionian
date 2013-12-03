require 'ionian/extension/socket'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  before do
    # Unix socket test server.
    @unix_socket_file = '/tmp/ionian.test.sock'
    File.delete @unix_socket_file if File.exists? @unix_socket_file
    @unix_server = UNIXServer.new @unix_socket_file
    
    @unix_server_thread = Thread.new do
      loop do
        begin
          break if @unix_server.closed?
          new_request = ::IO.select [@unix_server], nil, nil
          
          if new_request
            @unix_client.close if @unix_client and not @unix_client.closed?
            @unix_client = @unix_server.accept.extend Ionian::Extension::Socket
          end
        rescue Exception
          break
        end
      end
    end
    
    # wait_until { @unix_client }
  end
  
  after do
    @unix_server.close if @unix_server and not @unix_server.closed?
    @unix_server = nil
    File.delete @unix_socket_file if File.exists? @unix_socket_file
    
    @unix_server_thread.kill if @unix_server_thread
    Timeout.timeout 1 do; @unix_server_thread.join; end
  end
  
  
  before do
    # Object under test.
    @socket = @object = Ionian::Socket.new \
      host: 'localhost',
      port: @port
    
    # Non-persistent test socket.
    @socket_np = Ionian::Socket.new \
      host: 'localhost',
      port: @port,
      protocol: :tcp,
      persistent: false
  end
  
  after do
    @socket.close if @socket and not @socket.closed?
    @socket = @object = nil
  end
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  it "responds to protocol?" do
    @socket.should respond_to :protocol?
  end
  
  it "responds to persistent?" do
    @socket.should respond_to :persistent?
  end
  
  it "responds to cmd" do
    @socket.should respond_to :cmd
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
    @socket.closed?.should eq false
    
    # Send data.
    data = 'test'
    @socket.write data
    @socket.flush
    
    wait_until { !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should still be open.
    @socket.closed?.should eq false
  end
  
  it "can open a persistent UDP client (standard: stays open)" do
    @socket = Ionian::Socket.new host: 'localhost', port: @port, protocol: :udp
    @socket.persistent?.should eq true
    @socket.closed?.should eq false
    
    # Send data.
  end
  
  it "can open a persistent Unix client (standard: stays open)" do
    @socket = Ionian::Socket.new host: @unix_socket_file, protocol: :unix
    @socket.persistent?.should eq true
    @socket.closed?.should eq false
    
    # Send data.
    data = 'test'
    @socket.write data
    @socket.flush
    
    wait_until { @unix_client and @unix_client.has_data? }
    @unix_client.readpartial(0xFFFF).should eq data

    # Socket should still be open.
    @socket.closed?.should eq false
  end
  
  it "can open a non-persistent TCP client (closes after message received)" do
    @socket_np.persistent?.should eq false
    @socket_np.closed?.should eq true
    
    # Send data.
    data = 'test'
    @socket_np.write data
    
    # Flushing a non-persistent socket should have no effect;
    # the socket will flush and close on #write.
    @socket_np.flush
    
    wait_until { !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    @socket_np.closed?.should eq true
    
    # Send more data.
    data = 'another test'
    @socket_np.write data
    
    wait_until { !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    @socket_np.closed?.should eq true
  end
  
  it "can open a non-persistent Unix client (closes after message received)"
  
  it "igores the non-persistent flag for UDP sockets"
  
  it "can open a send-and-forget TCP client (closes after TX)"
  
  it "can open a send-and-forget Unix client (closes after TX)"
  
  it "ignores the send-and-forget flag for UDP sockets"
  
  it "can send a TCP command and receive a response"
  
  it "can send a UDP command and receive a response"
  
  it "can send a Unix socket command and receive a response"
  
  
  it "implements puts non-persistent" do
    @socket_np.should respond_to :puts
    
    data = 'test push method'
    @socket_np.puts data
    
    wait_until { !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq "#{data}\n"
  end
  
  it "implements << non-persistent" do
    @socket_np.should respond_to :<<
    
    data = 'test push operator'
    @socket_np << data
    @socket_np.flush
    
    wait_until { !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
  end
  
  
  it "can send a TCP command and receive a response - persistent" do
    pending
    
    data = 'tcp command test'
    @socket.cmd(data).should eq (data + "\n")
  end
  
  it "can send a TCP command and receive a response - non-persistent"
  
end