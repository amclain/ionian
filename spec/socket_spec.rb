require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/socket'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  it "can be instantiated as a TCP, UDP, Unix client socket"
  
  it "can open a TCP client as non-persistent (closes after message received)"
  
  it "can open a Unix client as non-persistent (closes after message received)"
  
  it "can open a TCP client as send-and-forget (closes after TX)"
  
  it "can open a Unix client as send-and-forget (closes after TX)"
  
end