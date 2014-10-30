require 'ionian/extension/socket'
require 'ionian/socket'
require 'timeout'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'


shared_examples "an ionian socket" do
  it "can write data with the '<<' operator" do
    data = 'test << operator'
    subject << data
    subject.flush
    
    wait_until { client and not client.closed? and client.has_data? }
    client.readpartial(0xFFFF).should eq data
  end
  
  it "can 'puts' data" do
    data = 'test push method'
    subject.puts data
    
    wait_until { client and not client.closed? and client.has_data? }
    client.readpartial(0xFFFF).should eq "#{data}\n"
  end
end


shared_examples "a persistent ionian socket" do
  it "can write data" do
    # Send data.
    data = 'test'
    subject.write data
    subject.flush
    
    wait_until { client and not client.closed? and client.has_data? }
    client.readpartial(0xFFFF).should eq data
    
    # Socket should still be open.
    subject.closed?.should eq false
  end
  
  it_behaves_like "an ionian socket"
end


shared_examples "a non-persistent ionian socket" do
  it "can write data" do
    # Send data.
    data = 'test'
    subject.write data
    
    # Flushing a non-persistent socket should have no effect;
    # the socket will flush and close on #write.
    subject.flush
    
    wait_until { client and not client.closed? and client.has_data? }
    client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    subject.closed?.should eq true
    
    # Send more data.
    data = 'another test'
    subject.write data
    
    wait_until { client and not client.closed? and client.has_data? }
    client.readpartial(0xFFFF).should eq data
    
    # Socket should be closed.
    subject.closed?.should eq true
  end
  
  it_behaves_like "an ionian socket"
end


describe Ionian::Socket do
  
  let(:kwargs) {{ host: 'localhost', port: port }}
  
  subject { Ionian::Socket.new **kwargs }
  after { subject.close if subject.respond_to? :close and not subject.closed? }
  
  
  describe "general" do
    include_context "tcp listener socket"
    
    it { should respond_to :host }
    it { should respond_to :port }
    it { should respond_to :bind_port }
    it { should respond_to :protocol }
  end
  
  
  describe "parse port from host string" do
    include_context "tcp listener socket"
    
    let(:host) { 'localhost' }
    let(:kwargs) {{ host: "#{host}:#{port}" }}
    
    its(:host) { should eq host }
    its(:port) { should eq port }
  end
  
  
  describe "initializer block" do
    include_context "tcp listener socket"
    
    around(:each) { |test| Timeout.timeout(1) { test.run } }
    
    let(:data) { "test initializer block\n" }
    
    subject {
      Ionian::Socket.new **kwargs do |socket|
        socket.write data
      end
      # Socket flushes and closes when block exits.
    }
    
    shared_examples "initializer block" do
      specify do
        subject
        sleep 0.1
        client.closed?.should eq false
        client.readpartial(0xFFFF).should eq data
        sleep 0.1
        subject.closed?.should eq true
      end
    end
    
    include_examples "initializer block"
    
    
    describe "socket is closed by developer" do
      include_examples "initializer block"
      
      subject {
        Ionian::Socket.new **kwargs do |socket|
          socket.write data
          
          # It is NOT necessary to close the socket inside the block,
          # but it shouldn't raise an exception if a developer does it.
          socket.close
        end
      }
    end
  end
  
  
  describe "on_match" do
    include_context "tcp listener socket"
    
    it "returns a match only once when run_match thread is running" do
      data = "test on_match\n"
      
      matches = []
      subject.on_match { matches << 1 }
      match_thread = subject.run_match
      
      sleep 0.1 # Wait for the client socket to be accepted.
      client.write data
      client.flush
      sleep 0.1
      
      match_thread.kill
      
      matches.count.should eq 1
    end
    
    it "returns a match only once when run_match thread is not running" do
      data = "test on_match\n"
      
      matches = []
      subject.on_match { matches << 1 }
      
      sleep 0.1 # Wait for the client socket to be accepted.
      client.write data
      client.flush
      sleep 0.1
      
      match = subject.read_match
      
      matches.count.should eq 1
    end
  end
  
  
  describe "existing socket" do
    subject { Ionian::Socket.new existing_socket }
    
    after {
      existing_socket.close unless existing_socket.closed?
      subject.close unless subject.closed?
    }
    
    
    describe "can convert an existing tcp socket" do
      include_context "tcp listener socket"
      
      let(:existing_socket) { TCPSocket.new 'localhost', kwargs[:port] }
      
      specify do
        subject.should be_an Ionian::Socket
        subject.closed?.should be false
        subject.protocol.should eq :tcp
        subject.persistent?.should eq true
      end
    end
    
    describe "can convert an existing udp socket" do
      include_context "udp listener socket"
      
      let(:existing_socket) { 
        UDPSocket.new.tap { |s| s.connect 'localhost', port }
      }
      
      specify do
        subject.should be_an Ionian::Socket
        subject.closed?.should be false
        subject.protocol.should be :udp
        subject.persistent?.should eq true
      end
    end
    
    describe "can convert an existing unix socket" do
      include_context "unix listener socket"
      
      let(:existing_socket) { UNIXSocket.new socket_file }
      
      specify do
        subject.should be_an Ionian::Socket
        subject.closed?.should be false
        subject.protocol.should be :unix
        subject.persistent?.should eq true
      end
    end
  end
  
  
  describe "with only host and port arguments given" do
    include_context "tcp listener socket"
    
    include_examples "ionian interface"
    include_examples "socket extension interface"
    
    its(:protocol)    { should eq :tcp }
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    it { should respond_to :cmd }
  end
  
  
  describe "with protocol: :tcp" do
    include_context "tcp listener socket"
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :tcp }}
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq TCPSocket }
    
    it_behaves_like "a persistent ionian socket"
  end
  
  
  describe "with protocol: :tcp, persistent: false" do
    # Non-persistent sockets seem like they should close after #write.
    # If the socket needs to receive a response before closing, #cmd
    # is the tool for the job, and may eliminate the need for a
    # :send_and_forget flag. This means #cmd should fire off MatchData
    # to the event handlers as well as returning it.
    
    # Non-persistent sockets should act like "send_and_forget: true":
    #   Data is transmitted and the respose is discarded.
    # Non-persistent command/response should be implemented using #cmd.
      
    include_context "tcp listener socket"
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :tcp, persistent: false }}
    
    its(:protocol?)   { should eq :tcp }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent ionian socket"
    
    it "can set the match expression outside the initializer" do
      expression = /my-expression\n/
      subject.expression = expression
      subject.expression.should eq expression
    end
    
    it "retains on_match handlers" do
      # Testing instance variables is a bad method, but the on_match
      # handlers won't trigger on non-persistent sockets unless #cmd
      # is called. #cmd can't be used in tests because it blocks before
      # data can be sent back to the subject socket.
      
      # Helper procs.
      socket_instance = proc{
        subject.instance_variable_get :@socket
      }
      
      listeners = proc{
          socket_instance.call.instance_variable_get :@ionian_listeners
      }
      
      # Send data, creating the socket instance with no listeners.
      subject.write "test\n"
      socket_instance_1 = socket_instance.call
      
      listeners.call.count.should eq 0
      
      # Register a match listener.
      subject.on_match { nil }
      listeners.call.count.should eq 1
      
      # Send more data, creating a new socket instance.
      subject.write "test\n"
      socket_instance_2 = socket_instance.call
      socket_instance_2.should_not eq socket_instance_1
      
      # The previous match listener should be passed to the new socket instance.
      listeners.call.count.should eq 1
    end
    
  end
  
  
  describe "with protocol: :unix" do
    include_context "unix listener socket"
    let(:kwargs) {{ host: socket_file, protocol: :unix }}
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UNIXSocket }
    
    it_behaves_like "a persistent ionian socket"
  end
  
  
  describe "with protocol: :unix, persistent: false" do
    include_context "unix listener socket"
    let(:kwargs) {{ host: socket_file, protocol: :unix, persistent: false }}
    
    its(:protocol?)   { should eq :unix }
    its(:persistent?) { should eq false }
    its(:closed?)     { should eq true }
    
    it_behaves_like "a non-persistent ionian socket"
  end
  
  
  describe "with protocol: :udp" do
    include_context "udp listener socket"
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :udp, bind_port: port + 1 }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    its(:multicast?)  { should eq false }
    
    specify { subject.instance_variable_get(:@socket).class.should eq UDPSocket }
    
    it_behaves_like "a persistent ionian socket"
  end
  
  
  describe "with protocol: :udp, persistent: false" do
    include_context "udp listener socket"
    let(:kwargs) {{ host: 'localhost', port: port, protocol: :udp, persistent: false, bind_port: port + 1 }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true } # UDP sockets are always persistent.
    its(:closed?)     { should eq false }
    
    # It ignores the non-persistent flag and...
    it_behaves_like "a persistent ionian socket"
  end
  
  
  describe "with protocol: :udp, multicast" do
    include_context "udp listener socket"
    # UDP protocol is implicit for a multicast address.
    let(:kwargs) {{ host: '224.0.0.5', port: port }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    its(:multicast?)  { should eq true }
    its(:reuse_addr?) { should eq true }
    
    it_behaves_like "a persistent ionian socket"
  end
  
  
  describe "with protocol: :udp, broadcast" do
    include_context "udp listener socket"
    let(:kwargs) {{ host: '255.255.255.255', port: port, broadcast: true }}
    
    its(:protocol?)   { should eq :udp }
    its(:persistent?) { should eq true }
    its(:closed?)     { should eq false }
    its(:multicast?)  { should eq false }
    its(:broadcast?)  { should eq true }
    its(:reuse_addr?) { should eq true }
    
    it_behaves_like "a persistent ionian socket"
  end
  
end
