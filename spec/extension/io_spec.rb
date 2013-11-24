require 'listener_socket_context'
require 'ionian_interface'
require 'ionian/extension/io'
require 'socket'
require 'timeout'

Thread.abort_on_exception = true

describe Ionian::Extension::IO do
  
  include_context "listener socket"
  
  include_examples "ionian interface"
  
  
  it "can get and set the IO timeout" do
    value = 5
    @ionian.ionian_timeout = value
    @ionian.ionian_timeout.should eq value
  end
  
  it "can get and set the regex match expression" do
    value = /test/
    @ionian.expression = value
    @ionian.expression.should eq value
  end
  
  it "can purge Ionian's read buffer" do
    @client.puts 'test data'
    @ionian.purge
    @ionian.read_match(timeout: 0).should eq nil
  end
  
  it "can read matched data" do
    @client.write "CS 1234 1\nCS 4567 0\n"
    @client.flush
    
    match = @ionian.read_match
    
    match[0].cmd.should   eq 'CS'
    match[0].param.should eq '1234'
    match[0].value.should eq '1'
    match[1].cmd.should   eq 'CS'
    match[1].param.should eq '4567'
    match[1].value.should eq '0'
  end
  
  it "can receive matched data on a listener" do
    block_run = false
    
    @ionian.on_match do |match, socket|
      match.cmd.should   eq 'CS'
      match.param.should eq '7890'
      match.value.should eq '1'
      
      block_run = true
    end
    
    thread = @ionian.run_match
    
    @client.write "CS 7890 1\n"
    @client.flush
    
    sleep 0.1
    thread.kill
    
    Timeout.timeout 1 do; thread.join; end
    block_run.should eq true
  end
  
  it "calls a listener block once for each match" do
    block_run = false
    match_count = 0
    
    @ionian.on_match do |match, socket|
      case match_count
      when 0
        match.cmd.should   eq 'CS'
        match.param.should eq '7890'
        match.value.should eq '1'
      when 1
        match.cmd.should   eq 'CS'
        match.param.should eq '2345'
        match.value.should eq '0'
        
        block_run = true
      end
      
      match_count += 1
    end
    
    thread = @ionian.run_match
    
    @client.write "CS 7890 1\nCS 2345 0\n"
    @client.flush
    
    sleep 0.1
    thread.kill
    
    Timeout.timeout 1 do; thread.join; end
    block_run.should eq true
  end
  
end