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
      
      xspecify do
        exceptions = []
        subject.on_error { |e| exceptions << e }
        
        (1..4).each do |i|
          clients.count.should eq i
          # exceptions.count.should eq i - 1
          
          client.close
          Timeout.timeout(1) { Thread.pass until clients.count == i + 1 }
          
          clients.count.should eq i + 1
          # exceptions.count.should eq i
        end
        
        p clients
        p exceptions
      end
    end
    
  end
  
end
