shared_examples "socket extension interface" do
  
  it "responds to no_delay" do
    @ionian.should respond_to :no_delay
  end
  
  it "responds to no_delay=" do
    @ionian.should respond_to :no_delay=
  end
  
end