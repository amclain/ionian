require 'ionian/managed_socket'

require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'

describe Ionian::ManagedSocket do
  
  subject { Ionian::ManagedSocket.new **kwargs }
  let(:kwargs) {{ host: host, port: port }}
  let(:host)   { 'localhost' }
  
  describe do
    include_context "tcp listener socket"
    include_examples "ionian interface"
    include_examples "socket extension interface"
  end
  
end
