require 'listener_socket_context'
require 'ionian/socket'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  # Server needs to be a separate class.
  it "can be instantitated as a TCP, UDP, Unix server socket"
  
  it "can be instantiated as a TCP, UDP, Unix client socket"
  
  it "extends the Ionian IO extentions"
  
  it "extends the Ionian socket extentions"
  
  it "can open a TCP client as non-persistent (closes after message received)"
  
  it "can open a Unix client as non-persistent (closes after message received)"
  
  it "can open a TCP client as send-and-forget (closes after TX)"
  
  it "can open a Unix client as send-and-forget (closes after TX)"
  
end