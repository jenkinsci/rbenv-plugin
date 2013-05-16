require 'stringio'
require 'shellwords'

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  display_name "Rbenv build wrapper"

  DEFAULT_RBENV_ROOT = "$HOME/.rbenv"
  RUBY_BUILD_PATH = "git://github.com/sstephenson/ruby-build.git"
  RBENV_PATH = "git://github.com/sstephenson/rbenv.git"

  attr_accessor :version

  def initialize(attrs = {})
    @version = attrs['version']
    @gem_list = attrs['gem_list']
  end

  def setup(build, launcher, listener)
    @launcher = launcher
    unless directory_exists?(rbenv_root)
      listener << "Install rbenv\n"
      run("git clone #{RBENV_PATH.shellescape} #{rbenv_root.shellescape}", {out: listener})
    end

    plugins_path = "#{rbenv_root}/plugins"
    ruby_build_path = "#{plugins_path}/ruby-build"
    unless directory_exists?(ruby_build_path)
      listener << "Install ruby-build\n"
      run("git clone #{RUBY_BUILD_PATH.shellescape} #{ruby_build_path.shellescape}", {out: listener})
    end

    rbenv_bin = "#{rbenv_root}/bin/rbenv"

    # Respect local Ruby version if defined in the workspace
    local_version = capture("cd #{build.workspace.to_s.shellescape} && #{rbenv_bin.shellescape} local 2>/dev/null || true").strip
    @version = local_version unless local_version.empty?

    versions = capture("#{rbenv_bin.shellescape} versions --bare").strip.split
    unless versions.include?(@version)
      # To update definitions, update rbenv and ruby-build before installing ruby
      listener << "Update rbenv\n"
      run("cd #{rbenv_root.shellescape} && git pull")
      listener << "Update ruby-build\n"
      run("cd #{ruby_build_path.shellescape} && git pull")
      listener << "Install #{@version}\n"
      run("#{rbenv_bin.shellescape} install #{@version.shellescape}", {out: listener})
    end

    gem_bin = "#{rbenv_root}/versions/#{@version}/bin/gem"
    list = capture("#{gem_bin.shellescape} list").strip.split
    (@gem_list || 'bundler,rake').split(',').each do |gem|
      unless list.include? gem
        listener << "Install #{gem}\n"
        run("#{gem_bin.shellescape} install #{gem.shellescape}", {out: listener})
        run("#{rbenv_bin.shellescape} rehash", {out: listener})
      end
    end

    build.env['RBENV_VERSION'] = @version
    build.env['PATH+RBENV'] = "#{rbenv_root}/shims"
  end

  def directory_exists?(path)
    execute("test -d #{path}") == 0
  end

  def rbenv_root
    @rbenv_root ||= capture("echo \"${RBENV_ROOT:-#{DEFAULT_RBENV_ROOT}}\"").strip
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
end
