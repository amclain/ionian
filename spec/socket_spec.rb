require 'listener_socket_context'
require 'ionian_interface'
require 'ionian/socket'

describe Ionian::Socket do
  
  include_context "listener socket", Ionian::Extension::Socket
  
  include_examples "ionian interface"
  
  
  it "can be instantiated as a TCP, UDP, Unix client socket"
  
  # it "extends the Ionian IO extentions" do
  #   @ionian.
  # end
  
  it "extends the Ionian socket extentions"
  
  it "can open a TCP client as non-persistent (closes after message received)"
  
  it "can open a Unix client as non-persistent (closes after message received)"
  
  it "can open a TCP client as send-and-forget (closes after TX)"
  
  it "can open a Unix client as send-and-forget (closes after TX)"
  
end