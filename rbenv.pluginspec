Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "rbenv"
  plugin.display_name = "rbenv plugin"
  plugin.version = '0.0.3'
  plugin.description = 'Run Jenkins builds in rbenv'

  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/Rbenv+Plugin'
  plugin.developed_by "hsbt", "shibata.hiroshi@gmail.com"

  plugin.uses_repository :github => "hsbt/jenkins-rbenv-plugin"

  plugin.depends_on 'ruby-runtime', '0.10'
  # plugin.depends_on 'git', '1.1.11'
end
