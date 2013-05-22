require 'stringio'
require 'shellwords'

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  display_name "rbenv build wrapper"

  attr_accessor :version
  attr_accessor :gem_list
  attr_accessor :ignore_local_version
  attr_accessor :rbenv_root
  attr_accessor :rbenv_repository
  attr_accessor :rbenv_revision
  attr_accessor :ruby_build_repository
  attr_accessor :ruby_build_revision

  def initialize(attrs = {})
    @version = attrs['version']
    @gem_list = attrs['gem_list']
    @ignore_local_version = attrs["ignore_local_version"]
    @rbenv_root = attrs["rbenv_root"]
    @rbenv_repository = attrs["rbenv_repository"]
    @rbenv_revision = attrs["rbenv_revision"]
    @ruby_build_repository = attrs["ruby_build_repository"]
    @ruby_build_revision = attrs["ruby_build_revision"]
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

    gem_bin = "#{rbenv_root}/shims/gem"
    list = capture("RBENV_ROOT=#{rbenv_root.shellescape} RBENV_VERSION=#{@version.shellescape} #{gem_bin.shellescape} list").strip.split
    (@gem_list || 'bundler,rake').split(',').each do |gem|
      unless list.include? gem
        listener << "Install #{gem}\n"
        run("RBENV_ROOT=#{rbenv_root.shellescape} RBENV_VERSION=#{@version.shellescape} #{gem_bin.shellescape} install #{gem.shellescape}", {out: listener})
      end
    end

    # Run rehash everytime to update binstubs
    run("RBENV_ROOT=#{rbenv_root.shellescape} #{rbenv_bin.shellescape} rehash", {out: listener})

    build.env["RBENV_ROOT"] = rbenv_root
    build.env['RBENV_VERSION'] = @version

    # Set ${RBENV_ROOT}/bin in $PATH to allow invoke rbenv from shell
    build.env['PATH+RBENV'] = ["#{rbenv_root}/bin".shellescape, "#{rbenv_root}/shims".shellescape].join(":")
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
end
