require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/kinesis"
require "logstash/codecs/plain"
require "logstash/event"
require "json"

describe LogStash::Outputs::Kinesis do
  let(:config) {{
    "stream_name" => "test",
    "region" => "ap-southeast-2",
    "metrics_level" => "none"
  }}
  let(:sample_event) {
    LogStash::Event.new({
      "message" => "hello",
      'stream_name' => 'my_stream',
      "field1"  => "foo",
      "field2"  => "bar"
    })
  }

  KPL = com.amazonaws.services.kinesis.producer

  context 'when initializing' do
    it "should register" do
      output = LogStash::Plugin.lookup("output", "kinesis").new(config)
      expect {output.register}.to_not raise_error
    end

    it 'should populate config with default values' do
      output = LogStash::Outputs::Kinesis.new(config)
      insist { output.randomized_partition_key } == false
      insist { output.event_partition_keys } == []
    end
  end

  context "when receiving message" do
    it "sends record to Kinesis" do
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)

      output = LogStash::Outputs::Kinesis.new (config)
      output.register
      output.receive(sample_event)
      output.close
    end

    it "should support Event#sprintf placeholders in stream_name" do
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)
        .with("my_stream", anything, anything)

      output = LogStash::Outputs::Kinesis.new(config.merge({
        "stream_name" => "%{stream_name}",
      }))
      output.register
      output.receive(sample_event)
      output.close
    end

    it "should support blank partition keys" do
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)
        .with(anything, "-", anything)

      output = LogStash::Outputs::Kinesis.new(config)
      output.register
      output.receive(sample_event)
      output.close
    end

    it "should support randomized partition keys" do
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)
        .with(anything, /[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+/, anything)

      output = LogStash::Outputs::Kinesis.new(config.merge({
        "randomized_partition_key" => true
      }))
      output.register
      output.receive(sample_event)
      output.close
    end

    it "should support fixed partition keys" do
      # the partition key ends up being an empty string plus the first field
      # we choose joined by a hyphen. this is a holdover from earlier versions
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)
        .with(anything, "-foo", anything)

      output = LogStash::Outputs::Kinesis.new(config.merge({
        "event_partition_keys" => ["[field1]", "[field2]"]
      }))
      output.register
      output.receive(sample_event)
      output.close
    end
  end

end
