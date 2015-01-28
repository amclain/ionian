require 'ionian/managed_socket'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

describe Ionian::ManagedSocket do
  
  subject { Ionian::ManagedSocket.new **kwargs }
  let(:kwargs) {{ host: host, port: port }}
  let(:host)   { 'localhost' }
  let(:skip_after_block) { false }
  
  after { subject.close if not skip_after_block and subject.respond_to? :close and not subject.closed? }
  
  def wait_until_client
    Thread.pass until client
  end
  
  
  describe do
    include_context "tcp listener socket"
    
    before { subject; wait_until_client }
    
    include_examples "ionian interface"
    include_examples "socket extension interface"
    
    describe "automatic reconnect" do
      let(:kwargs) {{ host: host, port: port, auto_reconnect: true, connect_timeout: 1 }}
      
      after  { subject.close }
      
      its(:auto_reconnect) { should eq true }
      
      it "binds match and error handlers to reconnected sockets" do
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
    end
    
  end
  
end
