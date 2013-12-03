
shared_examples "socket extension interface" do
  it { should respond_to :no_delay }
  it { should respond_to :no_delay= }
end
