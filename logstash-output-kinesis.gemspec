Gem::Specification.new do |s|
  s.name = 'logstash-output-kinesis'
  s.version         = "0.0.1"
  s.licenses = ["Apache License (2.0)"]
  s.summary = "This output plugin sends records to Kinesis using the Kinesis Producer Library (KPL)"
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install logstash-output-kinesis. This gem is not a stand-alone program"
  s.authors = ["Sam Day"]
  s.email = "me@samcday.com.au"
  s.homepage = "https://www.github.com/samcday/logstash-output-kinesis"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\).concat(Dir.glob("lib/**/*.jar")).concat(Dir.glob("lib/*_jars.rb"))
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Jar dependencies
  s.requirements << "jar 'com.amazonaws:amazon-kinesis-producer', '0.10.0'"

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 1.4.0", "< 2.0.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_runtime_dependency "logstash-codec-json"
  s.add_development_dependency "jar-dependencies"
  s.add_development_dependency "logstash-devutils"
end
