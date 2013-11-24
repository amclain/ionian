require 'listener_socket_context'
require 'extension/ionian_interface'
require 'extension/socket_extension_interface'
require 'ionian/socket'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  include_examples "socket extension interface"
  
  
  it "can be instantiated as a TCP client socket"
  
  it "can be instantiated as a UDP client socket"
  
  it "can be instantiated as a Unix client socket"
  
  it "defaults to TCP if the socket type is not specified"
  
  it "defaults to persistent"
  
  it "can open a persistent TCP client (standard: stays open)"
  
  it "can open a persistent UDP client (standard: stays open)"
  
  it "can open a persistent Unix client (standard: stays open)"
  
  it "can open a non-persistent TCP client (closes after message received)"
  
  it "can open a non-persistent Unix client (closes after message received)"
  
  it "igores the non-persistent flag for UDP sockets"
  
  it "can open a send-and-forget TCP client (closes after TX)"
  
  it "can open a send-and-forget Unix client (closes after TX)"
  
  it "ignores the send-and-forget flag for UDP sockets"
  
end