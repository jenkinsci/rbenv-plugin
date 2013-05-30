require 'stringio'
require 'shellwords'

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  TRANSIENT_INSTANCE_VARIABLES = [:launcher]
  class << self
    def transient?(symbol)
      # return true for a variable which should not be serialized
      TRANSIENT_INSTANCE_VARIABLES.include?(symbol)
    end
  end

  display_name "rbenv build wrapper"

  # FIXME: these values should be shared between views/rbenv_wrapper/config.erb
  DEFAULT_VERSION = "1.9.3p429"
  DEFAULT_GEM_LIST = "bundler,rake"
  DEFAULT_IGNORE_LOCAL_VERSION = false
  DEFAULT_RBENV_ROOT = "$HOME/.rbenv"
  DEFAULT_RBENV_REPOSITORY = "git://github.com/sstephenson/rbenv.git"
  DEFAULT_RBENV_REVISION = "master"
  DEFAULT_RUBY_BUILD_REPOSITORY = "git://github.com/sstephenson/ruby-build.git"
  DEFAULT_RUBY_BUILD_REVISION = "master"

  attr_accessor :version
  attr_accessor :gem_list
  attr_accessor :ignore_local_version
  attr_accessor :rbenv_root
  attr_accessor :rbenv_repository
  attr_accessor :rbenv_revision
  attr_accessor :ruby_build_repository
  attr_accessor :ruby_build_revision

  # The default values should be set on both instantiation and deserialization.
  def initialize(attrs={})
    load_attributes!(attrs)
  end

  # Will be invoked by jruby-xstream after deserialization from configuration file.
  def read_completed()
    load_attributes!
  end

  def setup(build, launcher, listener)
    @launcher = launcher
    unless directory_exists?(rbenv_root)
      listener << "Install rbenv\n"
      run(scm_checkout(rbenv_repository, rbenv_revision, rbenv_root), {out: listener})
    end

    plugins_path = "#{rbenv_root}/plugins"
    ruby_build_path = "#{plugins_path}/ruby-build"
    unless directory_exists?(ruby_build_path)
      listener << "Install ruby-build\n"
      run(scm_checkout(ruby_build_repository, ruby_build_revision, ruby_build_path), {out: listener})
    end

    rbenv_bin = "#{rbenv_root}/bin/rbenv"

    unless @ignore_local_version
      # Respect local Ruby version if defined in the workspace
      local_version = capture("cd #{build.workspace.to_s.shellescape} && #{rbenv_bin.shellescape} local 2>/dev/null || true").strip
      @version = local_version unless local_version.empty?
    end

    versions = capture("RBENV_ROOT=#{rbenv_root.shellescape} #{rbenv_bin.shellescape} versions --bare").strip.split
    unless versions.include?(@version)
      # To update definitions, update rbenv and ruby-build before installing ruby
      listener << "Update rbenv\n"
      run(scm_sync(rbenv_repository, rbenv_revision, rbenv_root), {out: listener})
      listener << "Update ruby-build\n"
      run(scm_sync(ruby_build_repository, ruby_build_revision, ruby_build_path), {out: listener})
      listener << "Install #{@version}\n"
      run("RBENV_ROOT=#{rbenv_root.shellescape} #{rbenv_bin.shellescape} install #{@version.shellescape}", {out: listener})
    end

    # Run rehash everytime before invoking gem
    run("RBENV_ROOT=#{rbenv_root.shellescape} #{rbenv_bin.shellescape} rehash", {out: listener})

    gem_bin = "#{rbenv_root}/shims/gem"
    list = capture("RBENV_ROOT=#{rbenv_root.shellescape} RBENV_VERSION=#{@version.shellescape} #{gem_bin.shellescape} list").strip.split
    (@gem_list || 'bundler,rake').split(',').each do |gem|
      unless list.include? gem
        listener << "Install #{gem}\n"
        run("RBENV_ROOT=#{rbenv_root.shellescape} RBENV_VERSION=#{@version.shellescape} #{gem_bin.shellescape} install #{gem.shellescape}", {out: listener})
      end
    end

    # Run rehash everytime after invoking gem
    run("RBENV_ROOT=#{rbenv_root.shellescape} #{rbenv_bin.shellescape} rehash", {out: listener})

    build.env["RBENV_ROOT"] = rbenv_root
    build.env['RBENV_VERSION'] = @version
    # Set ${RBENV_ROOT}/bin in $PATH to allow invoke rbenv from shell
    build.env["PATH+RBENV_BIN"] = "#{rbenv_root}/bin"
    # Set ${RBENV_ROOT}/shims in $PATH to allow invoke binstubs from shell
    build.env["PATH+RBENV_SHIMS"] = "#{rbenv_root}/shims"
  end

  private
  def directory_exists?(path)
    execute("test -d #{path}") == 0
  end

  def capture(command, options={})
    out = StringIO.new
    run(command, options.merge({out: out}))
    out.rewind
    out.read
  end

  def run(command, options={})
    if execute(command, options) != 0
      raise(RuntimeError.new("failed: #{command.inspect}"))
    end
  end

  def execute(command, options={})
    @launcher.execute("bash", "-c", command, options)
  end

  def scm_checkout(repository, revision, destination)
    execute = []
    execute << "git clone #{repository.shellescape} #{destination.shellescape}"
    execute << "cd #{destination.shellescape}"
    execute << "git checkout #{revision.shellescape}"
    execute.join(" && ")
  end

  def scm_sync(repository, revision, destination)
    execute = []
    execute << "cd #{destination.shellescape}"
    execute << "git fetch"
    execute << "git fetch --tags"
    execute << "git reset --hard #{revision}"
    execute.join(" && ")
  end

  def load_attributes!(attrs={})
    @version = attribute(attrs.fetch("version", @version), DEFAULT_VERSION)
    @gem_list = attribute(attrs.fetch("gem_list", @gem_list), DEFAULT_GEM_LIST)
    @ignore_local_version = attribute(attrs.fetch("ignore_local_version", @ignore_local_version), DEFAULT_IGNORE_LOCAL_VERSION)
    @rbenv_root = attribute(attrs.fetch("rbenv_root", @rbenv_root), DEFAULT_RBENV_ROOT)
    @rbenv_repository = attribute(attrs.fetch("rbenv_repository", @rbenv_repository), DEFAULT_RBENV_REPOSITORY)
    @rbenv_revision = attribute(attrs.fetch("rbenv_revision", @rbenv_revision), DEFAULT_RBENV_REVISION)
    @ruby_build_repository = attribute(attrs.fetch("ruby_build_repository", @ruby_build_repository), DEFAULT_RUBY_BUILD_REPOSITORY)
    @ruby_build_revision = attribute(attrs.fetch("ruby_build_revision", @ruby_build_revision), DEFAULT_RUBY_BUILD_REVISION)
  end

  # Jenkins may return empty string as attribute value which we must ignore
  def attribute(value, default_value=nil)
    str = value.to_s
    not(str.empty?) ? str : default_value
  end
end
