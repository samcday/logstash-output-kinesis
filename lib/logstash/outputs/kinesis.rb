# encoding: utf-8

require "java"
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash-output-kinesis_jars"

# Sends log events to a Kinesis stream. This output plugin uses the official Amazon KPL.
# Most of the configuration options in this plugin are simply passed on to
# link:https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.0/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L38[KinesisProducerConfiguration]
class LogStash::Outputs::Kinesis < LogStash::Outputs::Base
  config_name "kinesis"

  default :codec, 'json'

  # The name of the stream to send data to.
  config :stream_name, :validate => :string, :required => true
  # A list of event data keys to use when constructing a partition key
  config :event_partition_keys, :validate => :array, :default => []

  # An AWS access key to use for authentication to Kinesis and CloudWatch
  config :access_key, :validate => :string
  # An AWS secret key to use for authentication to Kinesis and CloudWatch
  config :secret_key, :validate => :string
  # If provided, STS will be used to assume this role and use it to authenticate to Kinesis and CloudWatch
  config :role_arn, :validate => :string

  # If provided, use this AWS access key for authentication to CloudWatch
  config :metrics_access_key, :validate => :string
  # If provided, use this AWS secret key for authentication to CloudWatch
  config :metrics_secret_key, :validate => :string
  # If provided, STS will be used to assume this role and use it to authenticate to CloudWatch
  config :metrics_role_arn, :validate => :string

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
  AWSAuth = com.amazonaws.auth
  ByteBuffer = java.nio.ByteBuffer

  public
  def register
    @metrics_access_key ||= @access_key
    @metrics_secret_key ||= @secret_key

    @producer = KPL.KinesisProducer::new(create_kpl_config)
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
    finished()
  end

  def create_kpl_config
    config = KPL.KinesisProducerConfiguration::new()

    credentials_provider = create_credentials_provider
    metrics_credentials_provider = create_metrics_credentials_provider

    config.setAggregationEnabled(@aggregation_enabled)
    config.setAggregationMaxCount(@aggregation_max_count)
    config.setAggregationMaxSize(@aggregation_max_size)
    config.setCollectionMaxCount(@collection_max_count)
    config.setCollectionMaxSize(@collection_max_size)
    config.setConnectTimeout(@connect_timeout)
    config.setCredentialsProvider(credentials_provider)
    config.setCredentialsRefreshDelay(@credentials_refresh_delay)
    config.setCustomEndpoint(@custom_endpoint) if !@custom_endpoint.nil?
    config.setFailIfThrottled(@fail_if_throttled)
    config.setLogLevel(@log_level)
    config.setMaxConnections(@max_connections)
    config.setMetricsCredentialsProvider(metrics_credentials_provider)
    config.setMetricsGranularity(@metrics_granularity)
    config.setMetricsLevel(@metrics_level)
    config.setMetricsNamespace(@metrics_namespace)
    config.setMetricsUploadDelay(@metrics_upload_delay)
    config.setMinConnections(@min_connections)
    config.setNativeExecutable(@native_executable) if !@native_executable.nil?
    config.setPort(@port)
    config.setRateLimit(@rate_limit)
    config.setRecordMaxBufferedTime(@record_max_buffered_time)
    config.setRecordTtl(@record_ttl)
    config.setRegion(@region)
    config.setRequestTimeout(@request_timeout)
    config.setTempDirectory(@temp_directory) if !@temp_directory.nil?
    config.setVerifyCertificate(@verify_certificate)

    config
  end

  def create_credentials_provider
    provider = AWSAuth.DefaultAWSCredentialsProviderChain.new()
    if @access_key and @secret_key
      provider = BasicCredentialsProvider.new(AWSAuth.BasicAWSCredentials.new(@access_key, @secret_key))
    end
    if @role_arn
      provider = AWSAuth.STSAssumeRoleSessionCredentialsProvider.new(provider, @role_arn, "logstash-output-kinesis")
    end
    provider
  end

  def create_metrics_credentials_provider
    provider = AWSAuth.DefaultAWSCredentialsProviderChain.new()
    if @metrics_access_key and @metrics_secret_key
      provider = BasicCredentialsProvider.new(AWSAuth.BasicAWSCredentials.new(@metrics_access_key, @metrics_secret_key))
    end
    if @metrics_role_arn
      provider = AWSAuth.STSAssumeRoleSessionCredentialsProvider.new(provider, @metrics_role_arn, "logstash-output-kinesis")
    end
    provider
  end

  def send_record(event, payload)
    begin
      event_blob = ByteBuffer::wrap(payload.to_java_bytes)
      @producer.addUserRecord(@stream_name, event["[@metadata][partition_key]"], event_blob)
    rescue => e
      @logger.warn("Error writing event to Kinesis", :exception => e, :event => event)
    end
  end
end

class BasicCredentialsProvider
  java_implements 'com.amazonaws.auth.AWSCredentialsProvider'

  def initialize(credentials)
    @credentials = credentials
  end

  java_signature 'com.amazonaws.auth.AWSCredentials getCredentials()'
  def getCredentials
    @credentials
  end

  java_signature 'void refresh()'
  def refresh
    # Noop.
  end
end
