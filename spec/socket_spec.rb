require 'ionian/extension/socket'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'


shared_examples "a persistent socket" do
  it "can write data" do
    # Send data.
    data = 'test'
    @socket.write data
    @socket.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should still be open.
    @socket.closed?.should eq false
  end
end


shared_examples "a non-persistent socket" do
  it "can write data" do
    # Send data.
    data = 'test'
    @socket.write data
    
    # Flushing a non-persistent socket should have no effect;
    # the socket will flush and close on #write.
    @socket.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    @socket.closed?.should eq true
    
    # Send more data.
    data = 'another test'
    @socket.write data
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    @socket.closed?.should eq true
  end
  
  it "can write data with the '<<' operator" do
    data = 'test << operator'
    @socket << data
    @socket.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
  end
  
  it "can 'puts' data" do
    data = 'test push method'
    @socket.puts data
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq "#{data}\n"
  end
end


describe Ionian::Socket do
  
  subject { @socket }
  
  after do
    @socket.close if @socket and not @socket.closed?
    @socket = @object = nil
  end
  
  describe "with only host and port arguments given" do
    include_context "listener socket", Ionian::Extension::Socket
    before do
      # Object under test.
      @socket = @object = Ionian::Socket.new \
        host: 'localhost',
        port: @port
    end
    
    include_examples "ionian interface"
    include_examples "socket extension interface"
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    it { should respond_to :cmd }
  end
  
  
  describe "with protocol: :tcp" do
    include_context "listener socket", Ionian::Extension::Socket
    before do
      @socket = Ionian::Socket.new \
        host: 'localhost', port: @port, protocol: :tcp
    end
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq TCPSocket }
    
    it_behaves_like "a persistent socket"
  end
  
  
  describe "with protocol: :tcp, persistent: false" do
    include_context "listener socket", Ionian::Extension::Socket
    before do
      @socket = Ionian::Socket.new \
        host: 'localhost', port: @port, protocol: :tcp, persistent: false
    end
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent socket"
  end
  
  
  describe "with protocol: :unix" do
    include_context "unix listener socket"
    before do
      @socket = Ionian::Socket.new \
        host: @socket_file, protocol: :unix
    end
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UNIXSocket }
    
    it_behaves_like "a persistent socket"
  end
  
  
  describe "with protocol: :unix, persistent: false" do
    include_context "unix listener socket"
    before do
      @socket = Ionian::Socket.new \
        host: @socket_file, protocol: :unix, persistent: false
    end
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent socket"
  end
  
  
  describe "with protocol: :udp" do
    # include_context "udp listener socket" # pending
    before do
      @socket = Ionian::Socket.new \
        host: 'localhost', port: @port, protocol: :udp
    end
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UDPSocket }
    
    it "behaves like a persistent socket"
    # it_behaves_like "a persistent socket" # pending
  end
  
  
  describe "with protocol: :udp, persistent: false" do
    # include_context "udp listener socket" # pending
    before do
      @socket = Ionian::Socket.new \
        host: 'localhost', port: @port, protocol: :udp, persistent: false
    end
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    # It ignores the non-persistent flag
    it "behaves like a persistent socket"
    # it_behaves_like "a persistent socket" # pending
  end
  
  # it "can open a send-and-forget TCP client (closes after TX)"
  
  # it "can open a send-and-forget Unix client (closes after TX)"
  
  # it "ignores the send-and-forget flag for UDP sockets"
  
  # it "can send a TCP command and receive a response"
  
  # it "can send a UDP command and receive a response"
  
  # it "can send a Unix socket command and receive a response"
  
  
  # it "can send a TCP command and receive a response - persistent" do
  #   pending
    
  #   data = 'tcp command test'
  #   @socket.cmd(data).should eq (data + "\n")
  # end
  
  # it "can send a TCP command and receive a response - non-persistent"
  
end