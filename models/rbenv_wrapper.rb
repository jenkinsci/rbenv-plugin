require "java"
require "rbenv"
require "rbenv/rack"
require "jenkins/rack"

class RbenvDescriptor < Jenkins::Model::DefaultDescriptor
  include Jenkins::RackSupport
  def call(env)
    Rbenv::RackApplication.new.call(env)
  end
end

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  TRANSIENT_INSTANCE_VARIABLES = [:build, :launcher, :listener]
  class << self
    def transient?(symbol)
      # return true for a variable which should not be serialized
      TRANSIENT_INSTANCE_VARIABLES.include?(symbol)
    end
  end

  describe_as Java.hudson.tasks.BuildWrapper, :with => RbenvDescriptor
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

  attr_reader :build
  attr_reader :launcher
  attr_reader :listener

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
    from_hash(attrs)
  end

  # Will be invoked by jruby-xstream after deserialization from configuration file.
  def read_completed()
    from_hash({})
  end

  def setup(build, launcher, listener)
    @build = build
    @launcher = launcher
    @listener = listener
    Rbenv::Environment.new(self).setup!
  end

  private
  def from_hash(hash)
    @version = attribute(hash.fetch("version", @version), DEFAULT_VERSION)
    @gem_list = attribute(hash.fetch("gem_list", @gem_list), DEFAULT_GEM_LIST)
    @ignore_local_version = attribute(hash.fetch("ignore_local_version", @ignore_local_version), DEFAULT_IGNORE_LOCAL_VERSION)
    @rbenv_root = attribute(hash.fetch("rbenv_root", @rbenv_root), DEFAULT_RBENV_ROOT)
    @rbenv_repository = attribute(hash.fetch("rbenv_repository", @rbenv_repository), DEFAULT_RBENV_REPOSITORY)
    @rbenv_revision = attribute(hash.fetch("rbenv_revision", @rbenv_revision), DEFAULT_RBENV_REVISION)
    @ruby_build_repository = attribute(hash.fetch("ruby_build_repository", @ruby_build_repository), DEFAULT_RUBY_BUILD_REPOSITORY)
    @ruby_build_revision = attribute(hash.fetch("ruby_build_revision", @ruby_build_revision), DEFAULT_RUBY_BUILD_REVISION)
  end

  # Jenkins may return empty string as attribute value which we must ignore
  def attribute(value, default_value=nil)
    str = value.to_s
    not(str.empty?) ? str : default_value
  end
end
