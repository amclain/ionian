
shared_examples "ionian interface" do
  it { should respond_to :initialize_ionian }
  it { should respond_to :has_data? }
  it { should respond_to :expression }
  it { should respond_to :expression= }
  it { should respond_to :read_match }
  it { should respond_to :run_match }
  it { should respond_to :purge }
  it { should respond_to :register_match_handler }
  it { should respond_to :on_match }
  it { should respond_to :unregister_match_handler }
  it { should respond_to :register_error_handler }
  it { should respond_to :on_error }
  it { should respond_to :unregister_error_handler }
end
