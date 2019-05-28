# encoding: utf-8

require "java"
require "logstash/outputs/base"
require "logstash/namespace"
require "securerandom"
require "logstash-output-kinesis_jars"

# Sends log events to a Kinesis stream. This output plugin uses the official Amazon KPL.
# Most of the configuration options in this plugin are simply passed on to
# link:https://github.com/awslabs/amazon-kinesis-producer/blob/v0.12.5/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L38[KinesisProducerConfiguration]
class LogStash::Outputs::Kinesis < LogStash::Outputs::Base
  config_name "kinesis"

  default :codec, 'json'

  # The name of the stream to send data to.
  config :stream_name, :validate => :string, :required => true
  # A list of event data keys to use when constructing a partition key
  config :event_partition_keys, :validate => :array, :default => []
  # If true, a random partition key will be assigned to each log record
  config :randomized_partition_key, :validate => :boolean, :default => false
  # If the number of records pending being written to Kinesis exceeds this number, then block
  # Logstash processing until they're all written.
  config :max_pending_records, :validate => :number, :default => 1000

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

  config :sts_proxy_host, :validate => :string
  config :sts_proxy_port, :validate => :number

  config :aggregation_enabled, :validate => :boolean, :default => true
  config :aggregation_max_count, :validate => :number, :default => 4294967295
  config :aggregation_max_size, :validate => :number, :default => 51200
  config :cloudwatch_endpoint, :validate => :string, :default => nil
  config :cloudwatch_port, :validate => :number, :default => 443
  config :collection_max_count, :validate => :number, :default => 500
  config :collection_max_size, :validate => :number, :default => 5242880
  config :connect_timeout, :validate => :number, :default => 6000
  config :credentials_refresh_delay, :validate => :number, :default => 5000
  config :enable_core_dumps, :validate => :boolean, :default => false
  config :fail_if_throttled, :validate => :boolean, :default => false
  config :kinesis_endpoint, :validate => :string, :default => nil
  config :kinesis_port, :validate => :number, :default => 443
  config :log_level, :validate => ["info", "warning", "error"], :default => "info"
  config :max_connections, :validate => :number, :default => 4
  config :metrics_granularity, :validate => ["global", "stream", "shard"], :default => "shard"
  config :metrics_level, :validate => ["none", "summary", "detailed"], :default => "detailed"
  config :metrics_namespace, :validate => :string, :default => "KinesisProducerLibrary"
  config :metrics_upload_delay, :validate => :number, :default => 60000
  config :min_connections, :validate => :number, :default => 1
  config :native_executable, :validate => :string, :default => nil
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

    if @randomized_partition_key
      event.set("[@metadata][partition_key]", SecureRandom.uuid)
    else
      # Haha - gawd. If I don't put an empty string in the array, then calling .join()
      # on it later will result in a US-ASCII string if the array is empty. Ruby is awesome.
      partition_key_parts = [""]

      @event_partition_keys.each do |partition_key_name|
        if not event.get(partition_key_name).nil? and event.get(partition_key_name).length > 0
          partition_key_parts << event.get(partition_key_name).to_s
          break
        end
      end

      event.set("[@metadata][partition_key]", (partition_key_parts * "-").to_s[/.+/m] || "-")
    end

    begin
      @codec.encode(event)
    rescue => e
      @logger.warn("Error encoding event", :exception => e, :event => event)
    end
  end

  public
  def close
    @producer.flushSync()
    @producer.destroy()
  end

  def create_kpl_config
    config = KPL.KinesisProducerConfiguration::new()

    credentials_provider = create_credentials_provider
    metrics_credentials_provider = create_metrics_credentials_provider

    config.setAggregationEnabled(@aggregation_enabled)
    config.setAggregationMaxCount(@aggregation_max_count)
    config.setAggregationMaxSize(@aggregation_max_size)
    config.setCloudwatchEndpoint(@cloudwatch_endpoint) if !@cloudwatch_endpoint.nil?
    config.setCloudwatchPort(@cloudwatch_port)
    config.setCollectionMaxCount(@collection_max_count)
    config.setCollectionMaxSize(@collection_max_size)
    config.setConnectTimeout(@connect_timeout)
    config.setCredentialsProvider(credentials_provider)
    config.setCredentialsRefreshDelay(@credentials_refresh_delay)
    config.setEnableCoreDumps(@enable_core_dumps)
    config.setFailIfThrottled(@fail_if_throttled)
    config.setLogLevel(@log_level)
    config.setKinesisEndpoint(@kinesis_endpoint) if !@kinesis_endpoint.nil?
    config.setKinesisPort(@kinesis_port)
    config.setMaxConnections(@max_connections)
    config.setMetricsCredentialsProvider(metrics_credentials_provider)
    config.setMetricsGranularity(@metrics_granularity)
    config.setMetricsLevel(@metrics_level)
    config.setMetricsNamespace(@metrics_namespace)
    config.setMetricsUploadDelay(@metrics_upload_delay)
    config.setMinConnections(@min_connections)
    config.setNativeExecutable(@native_executable) if !@native_executable.nil?
    config.setRateLimit(@rate_limit)
    config.setRecordMaxBufferedTime(@record_max_buffered_time)
    config.setRecordTtl(@record_ttl)
    config.setRegion(@region)
    config.setRequestTimeout(@request_timeout)
    config.setTempDirectory(@temp_directory) if !@temp_directory.nil?
    config.setVerifyCertificate(@verify_certificate)

    config
  end

  def create_sts_provider(base_provider, arn)
    client_config = com.amazonaws.ClientConfiguration.new()
    if @sts_proxy_host
      client_config.setProxyHost(@sts_proxy_host)
    end
    if @sts_proxy_port
      client_config.setProxyPort(@sts_proxy_port)
    end
    provider = AWSAuth.STSAssumeRoleSessionCredentialsProvider.new(
      base_provider, arn, "logstash-output-kinesis", client_config)
    provider
  end

  def create_credentials_provider
    provider = AWSAuth.DefaultAWSCredentialsProviderChain.new()
    if @access_key and @secret_key
      provider = BasicKinesisCredentialsProvider.new(AWSAuth.BasicAWSCredentials.new(@access_key, @secret_key))
    end
    if @role_arn
      provider = create_sts_provider(provider, @role_arn)
    end
    provider
  end

  def create_metrics_credentials_provider
    provider = AWSAuth.DefaultAWSCredentialsProviderChain.new()
    if @metrics_access_key and @metrics_secret_key
      provider = BasicKinesisCredentialsProvider.new(AWSAuth.BasicAWSCredentials.new(@metrics_access_key, @metrics_secret_key))
    end
    if @metrics_role_arn
      provider = create_sts_provider(provider, @metrics_role_arn)
    end
    provider
  end

  def send_record(event, payload)
    sleep 0.01 until @producer.getOutstandingRecordsCount() < @max_pending_records

    begin
      event_blob = ByteBuffer::wrap(payload.to_java_bytes)
      @producer.addUserRecord(event.sprintf(@stream_name), event.get("[@metadata][partition_key]"), event_blob)
    rescue => e
      @logger.warn("Error writing event to Kinesis", :exception => e)
    end
  end
end

class BasicKinesisCredentialsProvider
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
