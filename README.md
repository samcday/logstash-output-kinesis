# Kinesis Output Plugin

[![Build Status][badge-travis]][travis]
[![Gem info][badge-gem]][rubygems]
[![Code Climate][badge-codeclimate]][codeclimate]

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash).

It will send log records to a [Kinesis stream](https://aws.amazon.com/kinesis/), using the [KPL](https://docs.aws.amazon.com/kinesis/latest/dev/developing-producers-with-kpl.html) library.


## Configuration

Minimum required configuration to get this plugin chugging:

```
output {
  kinesis {
    stream_name => "logs-stream"
    region => "ap-southeast-2"
  }
}
```

This plugin accepts a wide range of configuration options, most of which come from the underlying KPL library itself.

[View the full list of KPL configuration options here.][kpldoc]

Please note that configuration options are snake_cased instead of camelCased. So, where [KinesisProducerConfiguration][kpldoc] offers a `setMetricsLevel` option,this plugin accepts a `metrics_level` option.

### AWS Credentials

Of course, there aren't terribly many Kinesis streams out there that allow you to write to them without some AWS credentials.

This plugin does not allow you to specify credentials directly. The AWS SDK [DefaultAWSCredentialsProviderChain](https://docs.aws.amazon.com/AWSJavaSDK/latest/javadoc/com/amazonaws/auth/DefaultAWSCredentialsProviderChain.html) is used, which is quite flexible. You can provide your credentials via any of the following mechanisms:

 * `AWS_ACCESS_KEY_ID` / `AWS_SECRET_KEY` environment variables
 * `~/.aws/credentials` credentials file
 * Instance profile for your running EC2 instance


### Building a partition key

Kinesis demands a [partition key](https://docs.aws.amazon.com/kinesis/latest/dev/key-concepts.html#partition-key) be provided for each record.

By default, this plugin will provide a very boring partition key of `-`. But, you can configure it to compute a partition key from fields in your log events.

```
output {
  kinesis {
    # ...
    event_partition_keys => ["[field1]", "[field2]"]
  }
}
```

This allows you to be flexible in how you partition your log data.


## Known Issues

### Noisy shutdown

During shutdown of Logstash, you might get noisy warnings like this:

```
[pool-1-thread-6] WARN com.amazonaws.services.kinesis.producer.Daemon - Exception during updateCredentials
java.lang.InterruptedException: sleep interrupted
at java.lang.Thread.sleep(Native Method)
at com.amazonaws.services.kinesis.producer.Daemon$5.run(Daemon.java:316)
at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:471)
at java.util.concurrent.FutureTask$Sync.innerRun(FutureTask.java:334)
at java.util.concurrent.FutureTask.run(FutureTask.java:166)
at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1145)
at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:615)
at java.lang.Thread.run(Thread.java:724)
```

This is caused by [amazon-kinesis-producer#10](https://github.com/awslabs/amazon-kinesis-producer/issues/10)


## Developing

```sh
bundle install
bundle exec rspec
```


## Contributions

Are more than welcome. Raising an issue is great, raising a PR is better, raising a PR with tests is best.


## License

[Apache License 2.0](LICENSE)

[travis]: https://travis-ci.org/samcday/logstash-output-kinesis
[rubygems]: https://rubygems.org/gems/logstash-output-kinesis
[codeclimate]: https://codeclimate.com/github/samcday/logstash-output-kinesis
[kpldoc]: https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.0/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L38

[badge-travis]: https://img.shields.io/travis/samcday/logstash-output-kinesis.svg?style=flat-square
[badge-gem]: https://img.shields.io/gem/v/logstash-output-kinesis.svg?style=flat-square
[badge-codeclimate]: https://img.shields.io/codeclimate/github/samcday/logstash-output-kinesis.svg?style=flat-square
[badge-coverage]: https://img.shields.io/codeclimate/coverage/github/samcday/logstash-output-kinesis.svg?style=flat-square
