require "rake/testtask"
require "rake/clean"

## jpi ##
begin
  require "jenkins/rake"
  Jenkins::Rake.install_tasks
  task :default => :package
rescue LoadError
end

## rspec ##
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

