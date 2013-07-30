require "java"
require "rbenv"
require "rbenv/rack"
require "jenkins/rack"

class RbenvDescriptor < Jenkins::Model::DefaultDescriptor
  DEFAULT_VERSION = "1.9.3p429"
  DEFAULT_GEM_LIST = "bundler,rake"
  DEFAULT_IGNORE_LOCAL_VERSION = false
  DEFAULT_RBENV_ROOT = "$HOME/.rbenv"
  DEFAULT_RBENV_REPOSITORY = "https://github.com/sstephenson/rbenv.git"
  DEFAULT_RBENV_REVISION = "master"
  DEFAULT_RUBY_BUILD_REPOSITORY = "https://github.com/sstephenson/ruby-build.git"
  DEFAULT_RUBY_BUILD_REVISION = "master"

  include Jenkins::RackSupport
  def call(env)
    Rbenv::RackApplication.new.call(env)
  end
end

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  TRANSIENT_INSTANCE_VARIABLES = [:build, :launcher, :listener]
  class << self
    def transient?(x)
      # return true for a variable which should not be serialized
      TRANSIENT_INSTANCE_VARIABLES.include?(x.to_s.to_sym)
    end
  end

  describe_as Java.hudson.tasks.BuildWrapper, :with => RbenvDescriptor
  display_name "rbenv build wrapper"

  # The default values should be set on both instantiation and deserialization.
  def initialize(attrs={})
    from_hash(attrs)
  end

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

  def to_hash()
    {
      "version" => @version,
      "gem_list" => @gem_list,
      "ignore_local_version" => @ignore_local_version,
      "rbenv_root" => @rbenv_root,
      "rbenv_repository" => @rbenv_repository,
      "rbenv_revision" => @rbenv_revision,
      "ruby_build_repository" => @ruby_build_repository,
      "ruby_build_revision" => @ruby_build_revision,
    }
  end

  private
  def from_hash(hash={})
    @version = string(hash.fetch("version", @version), RbenvDescriptor::DEFAULT_VERSION)
    @gem_list = string(hash.fetch("gem_list", @gem_list), RbenvDescriptor::DEFAULT_GEM_LIST)
    @ignore_local_version = boolean(hash.fetch("ignore_local_version", @ignore_local_version), RbenvDescriptor::DEFAULT_IGNORE_LOCAL_VERSION)
    @rbenv_root = string(hash.fetch("rbenv_root", @rbenv_root), RbenvDescriptor::DEFAULT_RBENV_ROOT)
    @rbenv_repository = string(hash.fetch("rbenv_repository", @rbenv_repository), RbenvDescriptor::DEFAULT_RBENV_REPOSITORY)
    @rbenv_revision = string(hash.fetch("rbenv_revision", @rbenv_revision), RbenvDescriptor::DEFAULT_RBENV_REVISION)
    @ruby_build_repository = string(hash.fetch("ruby_build_repository", @ruby_build_repository), RbenvDescriptor::DEFAULT_RUBY_BUILD_REPOSITORY)
    @ruby_build_revision = string(hash.fetch("ruby_build_revision", @ruby_build_revision), RbenvDescriptor::DEFAULT_RUBY_BUILD_REVISION)
  end

  # Jenkins may return empty string as attribute value which we must ignore
  def string(value, default_value=nil)
    s = value.to_s
    if s.empty?
      default_value
    else
      s
    end
  end

  def boolean(value, default_value=false)
    if FalseClass === value or TrueClass === value
      value
    else
      # rbenv plugin (<= 0.0.15) stores boolean values as String
      case value.to_s
      when /false/i then false
      when /true/i  then true
      else
        default_value
      end
    end
  end
end
