require 'ionian/extension/io'
require 'socket'
require 'timeout'


def wait_until(timeout_time=1)
  Timeout.timeout(timeout_time) { Thread.pass until yield }
end


shared_context "listener socket" do |extension|
  
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
            @client = @server.accept.extend Ionian::Extension::Socket
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


shared_context "unix listener socket" do
  
  before do
    # Unix socket test server.
    @socket_file = '/tmp/ionian.test.sock'
    File.delete @socket_file if File.exists? @socket_file
    @server = UNIXServer.new @socket_file
    
    @server_thread = Thread.new do
      loop do
        begin
          break if @server.closed?
          new_request = ::IO.select [@server], nil, nil
          
          if new_request
            @client.close if @client and not @client.closed?
            @client = @server.accept.extend Ionian::Extension::Socket
          end
        rescue Exception
          break
        end
      end
    end
    
    # wait_until { @client }
  end
  
  after do
    @server.close if @server and not @server.closed?
    @server = nil
    File.delete @socket_file if File.exists? @socket_file
    
    @server_thread.kill if @server_thread
    Timeout.timeout 1 do; @server_thread.join; end
  end
  
end