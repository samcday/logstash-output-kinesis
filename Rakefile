require "logstash/devutils/rake"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end

require 'jars/installer'
task :install_jars do
  # If we don't have these env variables set, jar-dependencies will
  # download the jars and place it in $PWD/lib/. We actually want them in
  # $PWD/vendor
  ENV['JARS_HOME'] = Dir.pwd + "/vendor/jar-dependencies/runtime-jars"
  ENV['JARS_VENDOR'] = "false"
  Jars::Installer.new.vendor_jars!(false)
end

task :vendor => :install_jars
task :default => [:vendor, :spec]
