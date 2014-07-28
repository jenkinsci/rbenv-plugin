#!/usr/bin/env ruby

require "rbenv/errors"

module Rbenv
  module Semaphore
    DEFAULT_ACQUIRE_MAX = 100
    DEFAULT_ACQUIRE_WAIT = 10
    DEFAULT_RELEASE_MAX = 100
    DEFAULT_RELEASE_WAIT = 10

    def synchronize(dir, options={})
      begin
        acquire_lock(dir, options)
        yield
      ensure
        release_lock(dir, options)
      end
    end

    def acquire_lock(dir, options={})
      max = options.fetch(:acquire_max, DEFAULT_ACQUIRE_MAX)
      wait = options.fetch(:acquire_wait, DEFAULT_ACQUIRE_WAIT)
      max.times do
        if test("mkdir #{dir.shellescape}")
          return true
        else
          sleep(wait)
        end
      end
      raise(LockError.new("could not acquire lock in #{max * wait} seconds."))
    end

    def release_lock(dir, options={})
      max = options.fetch(:release_max, DEFAULT_RELEASE_MAX)
      wait = options.fetch(:release_wait, DEFAULT_RELEASE_WAIT)
      max.times do
        if test("rm -rf #{dir.shellescape}") 
          return true
        else
          sleep(wait)
        end
      end
      raise(LockError.new("could not release lock in #{max * wait} secs."))
    end
  end
end
