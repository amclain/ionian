require 'ionian/extension/socket'

describe Ionian::Extension::Socket do
  
  before do
    @port = 5050
    
    @server = TCPServer.new @port
    
    @server_thread = Thread.new do
      @client = @server.accept
    end
    
    @ionian = @object = TCPSocket.new 'localhost', @port
    @ionian.extend Ionian::Extension::Socket
    
    Timeout.timeout 1 do; @server_thread.join; end
  end
  
  after do
    @ionian.close if @ionian
    @client.close if @client
    @server.close if @server
    @server_thread.kill if @server_thread
    
    @server = nil
    @client = nil
    @ionian = nil
    @server_thread = nil
  end
  
  it "provides accessors for tcp_nodelay" do
    @ionian.should respond_to :no_delay
    @ionian.should respond_to :no_delay=
    
    @ionian.no_delay = true
    @ionian.no_delay.should eq true
    
    @ionian.no_delay = false
    @ionian.no_delay.should eq false
  end
  
end