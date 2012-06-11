require 'stringio'

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  display_name "Rbenv build wrapper"

  RUBY_BUILD_PATH = "git://github.com/sstephenson/ruby-build.git"
  RBENV_PATH = "git://github.com/sstephenson/rbenv.git"

  attr_accessor :version

  def initialize(attrs = {})
    @version = attrs['version']
  end

  def setup(build, launcher, listener)
    install_path = "~/.rbenv/versions/#{@version}"

    unless FileTest.directory? File.expand_path("~/.rbenv")
      listener << "Install rbenv\n"
      launcher.execute("bash", "-c", "git clone #{RBENV_PATH} ~/.rbenv", {out: listener})
    end

    unless FileTest.directory? File.expand_path("~/.rbenv/plugins/ruby-build")
      listener << "Install ruby-build\n"
      launcher.execute("bash", "-c", "mkdir -p ~/.rbenv/plugins && cd ~/.rbenv/plugins && git clone #{RUBY_BUILD_PATH}", {out: listener})
    end

    unless FileTest.directory? File.expand_path(install_path)
      listener << "Install #{@version}\n"
      launcher.execute("bash", "-c", "~/.rbenv/bin/rbenv install #{@version}", {out: listener})
    end

    list = StringIO.new
    launcher.execute("bash", "-c", "#{install_path}/bin/gem list", {out: list})
    %w(bundler rake).each do |gem|
      unless list.string.include? gem
        listener << "Install #{gem}\n"
        launcher.execute("bash", "-c", "#{install_path}/bin/gem install #{gem}", {out: listener})
      end
    end

    build.env['PATH'] = "#{install_path}/bin:$PATH"
  end
end
