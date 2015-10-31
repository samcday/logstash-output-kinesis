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
  let(:sample_event) { LogStash::Event.new }

  KPL = com.amazonaws.services.kinesis.producer

  context "when receiving message" do
    it "sends record to Kinesis" do
      expect_any_instance_of(KPL::KinesisProducer).to receive(:addUserRecord)

      output = LogStash::Outputs::Kinesis.new (config)
      output.register
      output.receive(sample_event)
      output.close
    end
  end
end
