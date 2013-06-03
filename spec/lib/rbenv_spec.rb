require "spec_helper"
require "rbenv"

describe Rbenv::Environment do
  let(:build_wrapper) do
    stub
  end

  let(:rbenv) do
    Rbenv::Environment.new(build_wrapper)
  end

  it 'should respond to #setup!' do
    rbenv.respond_to?(:setup!).should == true
  end
end
