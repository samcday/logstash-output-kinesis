lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "logstash-output-kinesis/version"

Gem::Specification.new do |s|
  s.name = "logstash-output-kinesis"
  s.version = LogstashOutputKinesis::VERSION
  s.licenses = ["Apache License (2.0)"]
  s.summary = "This output plugin sends records to Kinesis using the Kinesis Producer Library (KPL)"
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install logstash-output-kinesis. This gem is not a stand-alone program"
  s.authors = ["Sam Day"]
  s.email = "me@samcday.com.au"
  s.homepage = "https://www.github.com/samcday/logstash-output-kinesis"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','Gemfile','LICENSE']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = {
    "logstash_plugin" => "true",
    "logstash_group" => "output"
  }

  s.platform = "java"

  # Jar dependencies
  s.requirements << "jar 'com.amazonaws:amazon-kinesis-producer', '0.12.3'"

  # KPL uses (1.11,1.12] as version range. Let's lock the version
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-core', '1.11.63'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-sts', '1.11.63'"
  s.requirements << "jar 'org.slf4j:slf4j-simple', '1.7.13'"

  s.add_runtime_dependency 'jar-dependencies', '~> 0.3.7'

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 2.0.0", "< 3.0.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_runtime_dependency "logstash-codec-json"
  s.add_development_dependency "logstash-devutils"
  s.add_development_dependency "gem-release", "~>0.7.3"
end
