require 'ionian/extension/io'
require 'socket'
require 'timeout'

# Raise exceptions out of child threads to interrupt main thread.
Thread.abort_on_exception = true

# Convenience method for waiting until a condition is true, with a timeout.
def wait_until(timeout: 1)
  Timeout.timeout(timeout) { Thread.pass; Thread.pass until Thread.exclusive { yield } }
end


shared_context "listener socket" do
  
  before do
    @server = server
    @server_thread = Thread.new do
      loop do
        begin
          break if @server.closed?
          new_request = ::IO.select [@server], nil, nil
          
          Thread.exclusive do
            if new_request
              @client.close if @client and not @client.closed?
              @client = @server.accept.extend Ionian::Extension::Socket
            end
          end
        rescue Exception
          break
        end
      end
    end
  end
  
  after do
    @client.close if @client and not @client.closed?
    @server.close if @server and not @server.closed?
    @server_thread.kill if @server_thread
    Timeout.timeout(1) { @server_thread.join } if @server_thread
    
    @client = nil
    @server = nil
    @server_thread = nil
  end
  
end


shared_context "tcp listener socket" do
  let(:port)   { 5050 }
  let(:server) { TCPServer.new port }
  
  include_context "listener socket"
end


shared_context "unix listener socket" do
  let(:socket_file) { '/tmp/ionian.test.sock' }
  let(:server)      { 
    File.delete socket_file if File.exists? socket_file
    UNIXServer.new socket_file
  }
  after { File.delete socket_file if File.exists? socket_file }
  
  include_context "listener socket"
end


shared_context "udp listener socket" do
  let(:port)   { 5050 }
  let(:server) { UDPSocket.new }
  let(:client) { server }
  
  before do
    @server = server
    @client = client
    
    server.extend Ionian::Extension::Socket
    server.bind Socket::INADDR_ANY, port
  end
  
  after do
    @server.close if @server and not @server.closed?
    @server = nil
    @client = nil
  end
  
end


shared_context "ionian subject" do |extension|
  include_context "tcp listener socket"
  subject { @ionian }
  
  before do
    @ionian = TCPSocket.new 'localhost', port
    
    # Can set the extension when including the context.
    @ionian.extend extension || Ionian::Extension::IO
    
    @ionian.expression = /(?<cmd>\w+)\s+(?<param>\d+)\s+(?<value>\d+)\s*?\r?\n?/
    
    # This prevents the tests from running until the client is created
    wait_until { @client }
  end
  
  after do
    @ionian.close if @ionian and not @ionian.closed?
    @ionian = nil
  end
  
end
