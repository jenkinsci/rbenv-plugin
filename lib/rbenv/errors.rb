#!/usr/bin/env ruby

module Rbenv
  class RbenvError < StandardError
  end

  class CommandError < RbenvError
  end

  class LockError < RbenvError
  end
end
