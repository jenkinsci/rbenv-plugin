require "spec_helper"
require "rbenv/semaphore"

describe Rbenv::Semaphore do
  let(:rbenv) do
    stub.extend(Rbenv::Semaphore)
  end

  let(:release_options) do
    {
      :acquire_max => 1,
      :acquire_wait => 1,
      :release_max => 1,
      :release_wait => 1,
    }
  end

  it "should acquire lock" do
    rbenv.should_receive(:test).with("mkdir true").and_return(true)
    rbenv.acquire_lock("true")
  end

  it "should not acquire lock" do
    rbenv.should_receive(:test).with("mkdir false").and_return(false)
    lambda { rbenv.acquire_lock("false", release_options) }.should raise_error(Rbenv::LockError)
  end

  it "should release lock" do
    rbenv.should_receive(:test).with("rmdir true").and_return(true)
    rbenv.release_lock("true")
  end

  it "should not release lock" do
    rbenv.should_receive(:test).with("rmdir false").and_return(false)
    lambda { rbenv.release_lock("false", release_options) }.should raise_error(Rbenv::LockError)
  end
end
