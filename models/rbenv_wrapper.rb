require 'stringio'

class RbenvWrapper < Jenkins::Tasks::BuildWrapper
  display_name "Rbenv build wrapper"

  attr_accessor :version

  def initialize(attrs = {})
    @version = attrs['version']
  end

  def setup(build, launcher, listener)
    if launcher.execute("bash", "-c", "test ! -d ~/.rbenv") == 0
      listener << "Install rbenv\n"
      launcher.execute("bash", "-c", "git clone git://github.com/sstephenson/rbenv.git ~/.rbenv", {out: listener})
    end

    if launcher.execute("bash", "-c", "test ! -d ~/.rbenv/plugins/ruby-build") == 0
      listener << "Install ruby-build\n"
      launcher.execute("bash", "-c", "mkdir -p ~/.rbenv/plugins && cd ~/.rbenv/plugins && git clone git://github.com/sstephenson/ruby-build.git", {out: listener})
    end

    if launcher.execute("bash", "-c", "test ! -d ~/.rbenv/versions/#{@version}") == 0
      listener << "Install #{@version}\n"
      launcher.execute("bash", "-c", "rbenv install #{@version}")
    end

    list = StringIO.new
    launcher.execute("bash", "-c", "~/.rbenv/versions/#{@version}/bin/gem list", {out: list})
    unless list.include? 'bundler'
      listener << "Install bundler\n"
      launcher.execute("bash", "-c", "~/.rbenv/versions/#{@version}/bin/gem install bundler")
    end

    build.env['PATH'] = "~/.rbenv/versions/#{@version}/bin:$PATH"
  end
end
