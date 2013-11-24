require 'ionian/extension/io'
require 'socket'

shared_context "listener socket" do |extension|
  
  before do
    @port = 5050
    
    @server = TCPServer.new @port
    
    @server_thread = Thread.new do
      @client = @server.accept
    end
    
    @ionian = @object = TCPSocket.new 'localhost', @port
    
    # Can set the extension when including the context.
    @ionian.extend extension || Ionian::Extension::IO
    
    @ionian.expression = /(?<cmd>\w+)\s+(?<param>\d+)\s+(?<value>\d+)\s*?[\r\n]+/
    
    Timeout.timeout 1 do; @server_thread.join; end
  end
  
  after do
    @ionian.close if @ionian
    @client.close if @client
    @server.close if @server
    @server_thread.kill if @server_thread
    
    @server = nil
    @client = nil
    @ionian = @object = nil
    @server_thread = nil
  end
end