#!/usr/bin/env ruby

require "shellwords"

module Rbenv
  module SCM
    class Base
      def initialize(repository, revision, destination)
        @repository = repository
        @revision = revision
        @destination = destination
      end
      attr_reader :repository
      attr_reader :revision
      attr_reader :destination
    end

    class Git < Base
      def checkout
        execute = []
        execute << "git clone #{repository.shellescape} #{destination.shellescape}"
        execute << "cd #{destination.shellescape}"
        execute << "git checkout #{revision.shellescape}"
        execute.join(" && ")
      end

      def sync
        execute = []
        execute << "cd #{destination.shellescape}"
        execute << "git checkout #{revision.shellescape}"
        execute << "git pull"
        execute.join(" && ")
      end
    end
  end
end
