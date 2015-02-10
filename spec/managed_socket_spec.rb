require 'ionian/managed_socket'

require_relative 'listener_socket_context'
require_relative 'extension/ionian_interface'
require_relative 'extension/socket_extension_interface'

describe Ionian::ManagedSocket,iso:true do
  subject { Ionian::ManagedSocket.new **kwargs }
  let(:kwargs) {{ host: host, port: port, auto_reconnect: auto_reconnect }}
  let(:host) { 'localhost' }
  let(:port) { 5050 }
  let(:auto_reconnect) { true }
  
  
  def wait_until_client
    Timeout.timeout(5) { Thread.pass until client }
  end
  
  
  describe "interface" do
    it { should respond_to :register_match_handler }
    it { should respond_to :on_match }
    it { should respond_to :write }
    it { should respond_to :close }
    it { should respond_to :run }
  end
  
  
  describe do
    include_context "tcp listener socket"
    let(:create_subject) { true }
    let(:matches) { [] }
    
    before {
      if create_subject
        subject.on_match { |match| matches << match }
        subject.run
        wait_until_client
      end
    }
    
    after { subject.close }
    
    describe "automatic reconnect" do
      let(:kwargs) {{ host: host, port: port, auto_reconnect: true, connect_timeout: 1 }}
      
      its(:auto_reconnect) { should eq true }
      
      xit "binds match and error handlers to reconnected sockets" do
        matches = []
        subject.on_match { |m| matches << m }
        
        exceptions = []
        subject.on_error { |e| exceptions << e } 
        
        (1..4).each do |i|
          clients.count.should eq i
          matches.count.should eq i - 1
          exceptions.count.should eq i - 1
          
          client.write "test\n"
          Timeout.timeout(1) { Thread.pass until matches.count == i }
          
          client.close
          
          Timeout.timeout(1) {
            Thread.pass until exceptions.count == i
            Thread.pass until clients.count == i + 1
          }
        end
      end
      
      # Issue #9
      describe "happens if the socket can't connect on the first try" do
        let(:create_subject) { false }
        
        xspecify do
          clients.count.should eq 0
          server.close
          server_thread.kill
          sleep 0.1
          
          Thread.new {
            sleep 1.5
            server = TCPServer.new port
            clients << server.accept
          }.run
          
          subject
          sleep 4
          
          clients.count.should eq 1
          
          subject.close
          server.close rescue IOError
        end
      end
    end
  end
  
  describe "raise error if auto_reconnect is not true" do
    let(:auto_reconnect) { false }
    specify { expect{subject}.to raise_error NotImplementedError }
  end
  
  describe "error handlers not implemented" do
    [:on_error, :register_error_handler, :unregister_error_handler].each do |meth|
      specify { expect{subject.__send__ meth}.to raise_error NotImplementedError }
    end
  end
  
end
