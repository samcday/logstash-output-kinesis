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
  s.files = `git ls-files`.split($\)
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = {
    "logstash_plugin" => "true",
    "logstash_group" => "output"
  }

  s.platform = "java"

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 1.4.0", "< 2.0.0"
  s.add_runtime_dependency "logstash-codec-plain", "< 2.0.0"
  s.add_runtime_dependency "logstash-codec-json", "< 2.0.0"
  s.add_development_dependency "logstash-devutils", "< 2.0.0"
  s.add_development_dependency "gem-release", "~>0.7.3"

  # Temporary hack because Logstash devs are crazy.
  # See: https://github.com/elastic/logstash/issues/4141
  # We should be able to remove this once logstash-core >2.0.0 && >1.5.5 are released
  s.add_development_dependency "concurrent-ruby", "0.9.1"
end
