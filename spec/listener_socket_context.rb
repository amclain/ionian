require 'ionian/extension/io'
require 'socket'
require 'timeout'

shared_context "listener socket" do |extension|
  
  def wait_until(timeout_time=1)
    Timeout.timeout(timeout_time) { Thread.pass until yield }
  end
  
  before do
    @port = 5050
    
    @server = TCPServer.new @port
    
    @server_thread = Thread.new do
      loop do
        begin
          break if @server.closed?
          new_request = ::IO.select [@server], nil, nil
          
          if new_request
            @client.close if @client and not @client.closed?
            @client = @server.accept
          end
        rescue Exception
          break
        end
      end
    end
    
    @ionian = @object = TCPSocket.new 'localhost', @port
    
    # Can set the extension when including the context.
    @ionian.extend extension || Ionian::Extension::IO
    
    @ionian.expression = /(?<cmd>\w+)\s+(?<param>\d+)\s+(?<value>\d+)\s*?[\r\n]+/
    
    # This prevents the tests from running until the client is created
    wait_until { @client }
  end
  
  after do
    @ionian.close if @ionian and not @ionian.closed?
    @client.close if @client and not @client.closed?
    @server.close if @server and not @server.closed?
    @server_thread.kill if @server_thread
    wait_until { @server_thread.join }
    
    @server = nil
    @client = nil
    @ionian = @object = nil
    @server_thread = nil
  end
  
end