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
    subject.write data
    subject.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should still be open.
    subject.closed?.should eq false
  end
end


shared_examples "a non-persistent socket" do
  it "can write data" do
    # Send data.
    data = 'test'
    subject.write data
    
    # Flushing a non-persistent socket should have no effect;
    # the socket will flush and close on #write.
    subject.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    subject.closed?.should eq true
    
    # Send more data.
    data = 'another test'
    subject.write data
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    subject.closed?.should eq true
  end
  
  it "can write data with the '<<' operator" do
    data = 'test << operator'
    subject << data
    subject.flush
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq data
  end
  
  it "can 'puts' data" do
    data = 'test push method'
    subject.puts data
    
    wait_until { @client and !@client.closed? and @client.has_data? }
    @client.readpartial(0xFFFF).should eq "#{data}\n"
  end
end


describe Ionian::Socket do
  
  let(:kwargs) {{ host: 'localhost', port: port }}
  
  subject { Ionian::Socket.new **kwargs }
  after { subject.close if subject.respond_to? :close and not subject.closed? }
  
  describe "with only host and port arguments given" do
    include_context "tcp listener socket", Ionian::Extension::Socket
    
    include_examples "ionian interface"
    include_examples "socket extension interface"
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    it { should respond_to :cmd }
  end
  
  
  describe "with protocol: :tcp" do
    include_context "tcp listener socket", Ionian::Extension::Socket
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :tcp }}
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq TCPSocket }
    
    it_behaves_like "a persistent socket"
  end
  
  
  describe "with protocol: :tcp, persistent: false" do
    include_context "tcp listener socket", Ionian::Extension::Socket
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :tcp, persistent: false }}
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent socket"
  end
  
  
  describe "with protocol: :unix" do
    include_context "unix listener socket"
    let(:kwargs) {{ host: socket_file, protocol: :unix }}
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UNIXSocket }
    
    it_behaves_like "a persistent socket"
  end
  
  
  describe "with protocol: :unix, persistent: false" do
    include_context "unix listener socket"
    let(:kwargs) {{ host: socket_file, protocol: :unix, persistent: false }}
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent socket"
  end
  
  
  describe "with protocol: :udp" do
    include_context "udp listener socket" # pending
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :udp }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UDPSocket }
    
    it "behaves like a persistent socket"
    # it_behaves_like "a persistent socket" # pending
  end
  
  
  describe "with protocol: :udp, persistent: false" do
    include_context "udp listener socket" # pending
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :udp, persistent: false }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    # It ignores the non-persistent flag and...
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
  #   subject.cmd(data).should eq (data + "\n")
  # end
  
  # it "can send a TCP command and receive a response - non-persistent"
  
end