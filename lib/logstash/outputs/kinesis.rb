# encoding: utf-8

require "logstash/outputs/base"
require "logstash/namespace"
require "java"

class LogStash::Outputs::Kinesis < LogStash::Outputs::Base
  config_name "kinesis-kpl"

  public
  def register

  end

  public
  def receive(event)
    return "Event received"
  end

  public
  def teardown
  end
end
