shared_examples "ionian interface" do
  
  it "responds to initialize_ionian" do
    @ionian.should respond_to :initialize_ionian
  end
  
  it "responds to has_data?" do
    @ionian.should respond_to :has_data?
  end
  
  it "responds to expression" do
    @ionian.should respond_to :expression
  end
  
  it "responds to expression=" do
    @ionian.should respond_to :expression=
  end
  
  it "responds to read_match" do
    @ionian.should respond_to :read_match
  end
  
  it "responds to run_match" do
    @ionian.should respond_to :run_match
  end
  
  it "responds to purge" do
    @ionian.should respond_to :purge
  end
  
  it "responds to register_observer" do
    @ionian.should respond_to :register_observer
  end
  
  it "responds to on_match" do
    @ionian.should respond_to :on_match
  end
  
  it "responds to unregister_observer" do
    @ionian.should respond_to :unregister_observer
  end
  
end