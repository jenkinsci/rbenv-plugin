#!/usr/bin/env ruby

require "delegate"
require "rbenv/errors"
require "rbenv/invoke"
require "rbenv/scm"
require "rbenv/semaphore"

module Rbenv
  class Environment < SimpleDelegator
    include Rbenv::InvokeCommand
    include Rbenv::Semaphore

    def initialize(build_wrapper)
      @build_wrapper = build_wrapper
      super(build_wrapper)
    end

    def setup!
      install!
      detect_version!

      # To avoid starting multiple build jobs, acquire lock during installation
      synchronize("#{rbenv_root}/.lock") do
        versions = capture(rbenv("versions", "--bare")).strip.split
        unless versions.include?(version)
          update!
          listener << "Installing #{version}..."
          run(rbenv("install", version), {out: listener})
          listener << "Installed #{version}."
        end
        gem_install!
      end

      build.env["RBENV_ROOT"] = rbenv_root
      build.env['RBENV_VERSION'] = version
      # Set ${RBENV_ROOT}/bin in $PATH to allow invoke rbenv from shell
      build.env["PATH+RBENV_BIN"] = "#{rbenv_root}/bin"
      # Set ${RBENV_ROOT}/bin in $PATH to allow invoke binstubs from shell
      build.env["PATH+RBENV_SHIMS"] = "#{rbenv_root}/shims"
    end

    private
    def install!
      unless test("[ -d #{rbenv_root.shellescape} ]")
        listener << "Installing rbenv..."
        run(Rbenv::SCM::Git.new(rbenv_repository, rbenv_revision, rbenv_root).checkout, {out: listener})
        listener << "Installed rbenv."
      end

      unless test("[ -d #{plugin_path("ruby-build").shellescape} ]")
        listener << "Installing ruby-build..."
        run(Rbenv::SCM::Git.new(ruby_build_repository, ruby_build_revision, plugin_path("ruby-build")).checkout, {out: listener})
        listener << "Installed ruby-build..."
      end
    end

    def detect_version!
      if ignore_local_version
        listener << "Just ignoring local Ruby version."
      else
        # Respect local Ruby version if defined in the workspace
        get_local_version(build.workspace.to_s).tap do |version|
          if version
            listener << "Use local Ruby version #{version}."
            self.version = version # call RbenvWrapper's accessor
          end
        end
      end
    end

    def get_local_version(path)
      str = capture("cd #{path.shellescape} && #{rbenv("local")} 2>/dev/null || true").strip
      not(str.empty?) ? str : nil
    end

    def update!
      # To update definitions, update rbenv before installing ruby
      listener << "Updating rbenv..."
      run(Rbenv::SCM::Git.new(rbenv_repository, rbenv_revision, rbenv_root).sync, {out: listener})
      listener << "Updated rbenv."

      listener << "Updating ruby-build..."
      run(Rbenv::SCM::Git.new(ruby_build_repository, ruby_build_revision, plugin_path("ruby-build")).sync, {out: listener})
      listener << "Updated ruby-build."
    end

    def gem_install!
      # Run rehash everytime before invoking gem
      run(rbenv("rehash"), {out: listener})

      list = capture(rbenv("exec", "gem", "list")).strip.split
      gem_list.split(",").each do |gem|
        unless list.include?(gem)
          listener << "Installing #{gem}..."
          run(rbenv("exec", "gem", "install", gem), {out: listener})
          listener << "Installed #{gem}."
        end
      end

      # Run rehash everytime after invoking gem
      run(rbenv("rehash"), {out: listener})
    end

    def rbenv(*args)
      (["env", "RBENV_ROOT=#{rbenv_root}",
               "RBENV_VERSION=#{version}",
               "CONFIGURE_OPTS=#{configure_opts}",
               "RUBY_CONFIGURE_OPTS=#{ruby_configure_opts}",
               "#{rbenv_root}/bin/rbenv"] + args).shelljoin
    end

    def plugin_path(name)
      File.join(rbenv_root, "plugins", name)
    end
  end
end
