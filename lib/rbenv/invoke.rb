#!/usr/bin/env ruby

require "rbenv/errors"
require "stringio"

module Rbenv
  module InvokeCommand
    def capture(command, options={})
      options = {out: StringIO.new}.merge(options)
      out = options[:out]
      run(command, options)
      out.rewind
      out.read
    end

    def run(command, options={})
      unless test(command, options)
        raise(CommandError.new("failed: #{command.inspect}"))
      end
    end

    def test(command, options={})
      invoke(command, options) == 0
    end

    def invoke(command, options={})
      launcher.execute("bash", "-c", command, options)
    end
  end
end
