# encoding: utf-8

require "java"
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash-output-kinesis_jars"

class LogStash::Outputs::Kinesis < LogStash::Outputs::Base
  config_name "kinesis"
  milestone 1

  default :codec, 'json'

  config :stream_name, :validate => :string, :required => true
  config :event_partition_keys, :validate => :array, :default => []

  config :aggregation_enabled, :validate => :boolean, :default => true
  config :aggregation_max_count, :validate => :number, :default => 4294967295
  config :aggregation_max_size, :validate => :number, :default => 51200
  config :collection_max_count, :validate => :number, :default => 500
  config :collection_max_size, :validate => :number, :default => 5242880
  config :connect_timeout, :validate => :number, :default => 6000
  config :credentials_refresh_delay, :validate => :number, :default => 5000
  config :custom_endpoint, :validate => :string, :default => nil
  config :fail_if_throttled, :validate => :boolean, :default => false
  config :log_level, :validate => :string, :default => "info"
  config :max_connections, :validate => :number, :default => 4
  config :metrics_granularity, :validate => ["global", "stream", "shard"], :default => "shard"
  config :metrics_level, :validate => ["none", "summary", "detailed"], :default => "detailed"
  config :metrics_namespace, :validate => :string, :default => "KinesisProducerLibrary"
  config :metrics_upload_delay, :validate => :number, :default => 60000
  config :min_connections, :validate => :number, :default => 1
  config :native_executable, :validate => :string, :default => nil
  config :port, :validate => :number, :default => 443
  config :rate_limit, :validate => :number, :default => 150
  config :record_max_buffered_time, :validate => :number, :default => 100
  config :record_ttl, :validate => :number, :default => 30000
  config :region, :validate => :string, :required => true
  config :request_timeout, :validate => :number, :default => 6000
  config :temp_directory, :validate => :string, :default => nil
  config :verify_certificate, :validate => :boolean, :default => true

  KPL = com.amazonaws.services.kinesis.producer
  ByteBuffer = java.nio.ByteBuffer

  public
  def register
    @kpl_config = KPL.KinesisProducerConfiguration::new()
      .setAggregationEnabled(@aggregation_enabled)
      .setAggregationMaxCount(@aggregation_max_count)
      .setAggregationMaxSize(@aggregation_max_size)
      .setCollectionMaxCount(@collection_max_count)
      .setCollectionMaxSize(@collection_max_size)
      .setConnectTimeout(@connect_timeout)
      .setCredentialsRefreshDelay(@credentials_refresh_delay)
      .setFailIfThrottled(@fail_if_throttled)
      .setLogLevel(@log_level)
      .setMaxConnections(@max_connections)
      .setMetricsGranularity(@metrics_granularity)
      .setMetricsLevel(@metrics_level)
      .setMetricsNamespace(@metrics_namespace)
      .setMetricsUploadDelay(@metrics_upload_delay)
      .setMinConnections(@min_connections)
      .setPort(@port)
      .setRateLimit(@rate_limit)
      .setRecordMaxBufferedTime(@record_max_buffered_time)
      .setRecordTtl(@record_ttl)
      .setRegion(@region)
      .setRequestTimeout(@request_timeout)
      .setVerifyCertificate(@verify_certificate)

    if !@native_executable.nil?
      @kpl_config = @kpl_config.setNativeExecutable(@native_executable)
    end

    if !@temp_directory.nil?
      @kpl_config = @kpl_config.setTempDirectory(@temp_directory)
    end

    if !@custom_endpoint.nil?
      @kpl_config = @kpl_config.setCustomEndpoint(@custom_endpoint)
    end

    @producer = KPL.KinesisProducer::new(@kpl_config)

    @codec.on_event(&method(:send_record))
  end

  public
  def receive(event)
    return unless output?(event)

    # Haha - gawd. If I don't put an empty string in the array, then calling .join()
    # on it later will result in a US-ASCII string if the array is empty. Ruby is awesome.
    partition_key_parts = [""]

    @event_partition_keys.each do |partition_key_name|
      if not event[partition_key_name].nil? and event[partition_key_name].length > 0
        partition_key_parts << event[partition_key_name].to_s
        break
      end
    end

    event["[@metadata][partition_key]"] = (partition_key_parts * "-").to_s[/.+/m] || "-"

    begin
      @codec.encode(event)
    rescue => e
      @logger.warn("Error encoding event", :exception => e, :event => event)
    end
  end

  public
  def teardown
    @producer.flushSync()
    @producer.destroy()
  end

  def send_record(event, payload)
    event_blob = ByteBuffer::wrap(payload.to_java_bytes)
    @producer.addUserRecord(@stream_name, event["[@metadata][partition_key]"], event_blob)
  end
end
