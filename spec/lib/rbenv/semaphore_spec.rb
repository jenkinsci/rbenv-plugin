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
    File.should_receive(:open).with("foobar/.rbenv_hold_lock","w")
    rbenv.acquire_lock("true","foobar")
  end

  it "should not acquire lock" do
    rbenv.should_receive(:test).with("mkdir false").and_return(false)
    lambda { rbenv.acquire_lock("false","foobar", release_options) }.should raise_error(Rbenv::LockError)
  end

  it "should release lock" do
    File.should_receive(:file?).with("foobar/.rbenv_hold_lock").and_return(true)
    FileUtils.should_receive(:rm).with("foobar/.rbenv_hold_lock")
    rbenv.should_receive(:test).with("rm -rf true").and_return(true)
    rbenv.release_lock("true","foobar")
  end

end
