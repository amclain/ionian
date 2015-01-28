require 'ionian/extension/io'
require 'socket'
require 'timeout'

# Convenience method for waiting until a condition is true, with a timeout.
def wait_until timeout: 1
  Timeout.timeout(timeout) { Thread.pass; Thread.pass until Thread.exclusive { yield } }
end


shared_context "listener socket" do
  
  def client
    clients.last
  end
  
  let(:clients) { [] }
  
  let!(:server_thread) {
    server
    Thread.new do
      begin
        while not server.closed?
          new_request = ::IO.select [server], nil, nil
          
          Thread.exclusive { clients << server.accept.extend(Ionian::Extension::Socket) } \
            if new_request
        end
      rescue IOError # closed
      end
    end
  }
  
  after {
    clients.each {|c| c.close unless c.closed?}
    server.close unless server.closed?
    server_thread.kill
    Timeout.timeout(1) { server_thread.join }
  }
  
end


shared_context "tcp listener socket" do
  let (:port)   { 5050 }
  let (:server) { TCPServer.new port }
  
  include_context "listener socket"
end


shared_context "unix listener socket" do
  let (:socket_file) { '/tmp/ionian.test.sock' }
  let (:server)      { 
    File.delete socket_file if File.exists? socket_file
    UNIXServer.new socket_file
  }
  after { File.delete socket_file if File.exists? socket_file }
  
  include_context "listener socket"
end


shared_context "udp listener socket" do
  let  (:port)   { 5050 }
  let  (:client) { server }
  let! (:server) {
    UDPSocket.new.tap do |s|
      s.extend Ionian::Extension::Socket
      s.reuse_addr = true
      s.bind Socket::INADDR_ANY, port
    end
  }
end


shared_context "ionian subject" do |extension|
  include_context "tcp listener socket"
  
  let! (:ionian_socket) {
    TCPSocket.new('localhost', port).tap do |s|
      s.extend extension || Ionian::Extension::IO
      s.expression = /(?<cmd>\w+)\s+(?<param>\d+)\s+(?<value>\d+)\s*?\r?\n?/
      
      wait_until { client }
    end
  }
  subject { ionian_socket }
  
  after { ionian_socket.close unless ionian_socket.closed? }
end
