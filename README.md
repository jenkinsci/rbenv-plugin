# Jenkins rbenv plugin

 rbenv build wrapper for Jenkins

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Building the plugin from source

Follow these steps if you are interested in hacking on the plugin.

Find a version of JRuby to install via `rbenv-install -l`

Install JRuby

    rbenv install jruby-1.6.7
    rbenv local jruby-1.6.7

Install the development gems

    bundle install
    rbenv rehash

Build the plugin

    rake package
    

Look at [Getting Started with Ruby Plugins](https://github.com/jenkinsci/jenkins.rb/wiki/Getting-Started-With-Ruby-Plugins) to get up to speed on things.
