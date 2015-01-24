require 'listener_socket_context'
require 'extension/ionian_interface'
require 'ionian/extension/io'
require 'socket'
require 'timeout'


describe Ionian::Extension::IO do
  
  include_context "ionian subject", Ionian::Extension::IO
  
  include_examples "ionian interface"
  
  it "can get and set the IO timeout" do
    value = 5
    subject.ionian_timeout = value
    subject.ionian_timeout.should eq value
  end
  
  it "can get and set the regex match expression" do
    value = /test/
    subject.expression = value
    subject.expression.should eq value
  end
  
  it "can purge Ionian's read buffer" do
    client.puts 'test data'
    subject.purge
    subject.read_match(timeout: 0).should eq nil
  end
  
  it "can read matched data" do
    client.write "CS 1234 1\nCS 4567 0\n"
    
    match = subject.read_match
    
    match[0].cmd.should   eq 'CS'
    match[0].param.should eq '1234'
    match[0].value.should eq '1'
    match[1].cmd.should   eq 'CS'
    match[1].param.should eq '4567'
    match[1].value.should eq '0'
  end
  
  it "attaches named captures as methods inside the block" do
    client.write "CS 1234 1\n"
    
    received_matches = false
    
    subject.read_match do |match|
      received_matches = true
      
      match.cmd.should   eq 'CS'
      match.param.should eq '1234'
      match.value.should eq '1'
    end
    
    received_matches.should eq true
  end
  
  it "can receive matched data on a listener" do
    block_run = false
    
    subject.on_match do |match, socket|
      match.cmd.should   eq 'CS'
      match.param.should eq '7890'
      match.value.should eq '1'
      
      block_run = true
    end
    
    thread = subject.run_match
    
    client.write "CS 7890 1\n"
    
    Timeout.timeout(1) {
      Thread.pass until block_run
      thread.kill
    }
    
    block_run.should eq true
  end
  
  it "calls a listener block once for each match" do
    block_run = false
    match_count = 0
    
    subject.on_match do |match, socket|
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
    
    thread = subject.run_match
    
    client.write "CS 7890 1\nCS 2345 0\n"
    
    Timeout.timeout(1) {
      Thread.pass until block_run
      thread.kill
    }
    
    block_run.should eq true
  end
  
  it "can set the match expression in a #read_match kwarg" do
    expression = /(?<param1>\w+)\s+(?<param2>\w+)\s*[\r\n]+/
    data = "hello world\n"
    subject
    
    client.write data
    
    match = subject.read_match expression: expression
    match = match.first
    
    match.param1.should eq 'hello'
    match.param2.should eq 'world'
  end
  
  it "notifies listeners on #read_match" do
    data = "CS 1234 65535\n"
    match_triggered = false
    
    subject.on_match { match_triggered = true }
    
    client.write data
    
    match = subject.read_match
    match_triggered.should eq true
  end
  
  it "does not notify #read_match listeners if notify:false is set" do
    data = "CS 1234 65535\n"
    match_triggered = false
    
    subject.on_match { match_triggered = true }
    
    client.write data
    
    match = subject.read_match notify: false
    match.should_not be nil
    match_triggered.should eq false
  end
  
  it "can read all of the data in the buffer" do
    repeat = 8192 # 100 killobytes.
    
    data = ''
    repeat.times { data += '1111111111111111' }
    
    subject
    client.write data
    
    result = subject.read_all
    
    result.size.should eq data.size
    result.should eq data
  end
  
  it "can match large data in the buffer" do
    repeat = 8192 # 100 killobytes.
    terminator = '0'
    
    data = ''
    repeat.times { data += '1111111111111111' }
    data << terminator
    
    subject.expression = /(?<data>1+)(?<term>0)/
    client.write data
    
    match = []
    Timeout.timeout(5) { match = subject.read_match }
    
    match.empty?.should eq false
    match.first.data.should eq data.chop
    match.first.term.should eq terminator
  end
  
  it "can match data that arrives in fragments" do
    terminator = '0'
    data = '11111111'
    repeat = 3
    
    subject.expression = /(?<data>1+)(?<term>0)/
    
    result = nil
    found_match = false
    
    # Match handler.
    subject.on_match do |match|
      result = match
      found_match = true
    end
    
    # Start looking for matches.
    thread = subject.run_match
    
    begin
      Timeout.timeout 10 do
        client.no_delay = true
        
        # Feed data into the socket.
        repeat.times do
          client.write data
          client.flush
        end
        
        client.write terminator
        client.flush
        Thread.pass until found_match
      end
    ensure
      thread.kill # Make sure the run_match thread dies.
    end
    
    found_match.should eq true
    
    # Replicate the data that should have been received.
    expected_data = ''
    repeat.times { expected_data += data }
    
    result.data.should eq expected_data
    result.term.should eq terminator
  end
  
  
  describe "read_all" do
    
    it "has blocking mode" do
      data = "CS 1234 65535\n"
      result = nil
      
      # Block if no data.
      begin
        Timeout.timeout(1) { result = subject.read_all }
      rescue Timeout::Error
      end
      
      result.should eq nil
      
      client.write data
      
      # Receive avalable data.
      Timeout.timeout(1) { result = subject.read_all }
      result.should eq data
    end
    
    it "has nonblocking mode" do
      data = "CS 1234 65535\n"
      result = 'error' # Junk data. Nonblocking should return nil if no data.
      
      # Block if no data.
      begin
        Timeout.timeout(1) { result = subject.read_all nonblocking: true }
      rescue Timeout::Error
      end
      
      result.should eq nil
      
      client.write data
      
      # Receive avalable data.
      Timeout.timeout(1) { result = subject.read_all nonblocking: true }
      result.should eq data
    end
    
  end
  
end