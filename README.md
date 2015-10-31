# Kinesis Output Plugin

[![Build Status][badge-travis]][travis]
[![Gem info][badge-gem]][rubygems]

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash). It will send log records to a [Kinesis stream](https://aws.amazon.com/kinesis/), using the [Kinesis Producer Library (KPL)](https://docs.aws.amazon.com/kinesis/latest/dev/developing-producers-with-kpl.html).

**This version is intended for use with Logstash 2.x. Please use a [1.5.x](https://github.com/samcday/logstash-output-kinesis/tree/1.5) version of this plugin for Logstash 1.5.x compatibility.**


## Configuration

Minimum required configuration to get this plugin chugging along:

```nginx
output {
  kinesis {
    stream_name => "logs-stream"
    region => "ap-southeast-2"
  }
}
```

This plugin accepts a wide range of configuration options, most of which come from the underlying KPL library itself. [View the full list of KPL configuration options here.][kpldoc]

Please note that configuration options are snake_cased instead of camelCased. So, where [KinesisProducerConfiguration][kpldoc] offers a `setMetricsLevel` option, this plugin accepts a `metrics_level` option.

### Metrics

The underlying KPL library defaults to sending CloudWatch metrics to give insight into what it's actually doing at runtime. It's highly recommended you ensure these metrics are flowing through, and use them to monitor the health of your log shipping.

If for some reason you want to switch them off, you can easily do so:

```nginx
output {
  kinesis {
    # ...

    metrics_level => "none"
  }
}
```

If you choose to keep metrics enabled, ensure the AWS credentials you provide to this plugin are able to write to Kinesis *and* write to CloudWatch.

### Authentication

By default, this plugin will use the AWS SDK [DefaultAWSCredentialsProviderChain](https://docs.aws.amazon.com/AWSJavaSDK/latest/javadoc/com/amazonaws/auth/DefaultAWSCredentialsProviderChain.html) to obtain credentials for communication with the Kinesis stream (and CloudWatch, if metrics are enabled). The following places will be checked for credentials:

 * `AWS_ACCESS_KEY_ID` / `AWS_SECRET_KEY` environment variables available to the Logstash prociess
 * `~/.aws/credentials` credentials file
 * Instance profile (if Logstash is running in an EC2 instance)

If you want to provide credentials directly in the config file, you can do so:

```nginx
output {
  kinesis {
    # ...

    access_key => "AKIAIDFAKECREDENTIAL"
    secret_key => "KX0ofakeLcredentialsGrightJherepOlolPkQk"

    # You can provide specific credentials for CloudWatch metrics:
    metrics_access_key => "AKIAIDFAKECREDENTIAL"
    metrics_secret_key => "KX0ofakeLcredentialsGrightJherepOlolPkQk"
  }
}
```

If `access_key` and `secret_key` are provided, they will be used for communicating with Kinesis *and* CloudWatch. If `metrics_access_key` and `metrics_secret_key` are provided, they will be used for communication with CloudWatch. If only the metrics credentials were provided, Kinesis would use the default credentials provider (explained above) and CloudWatch would use the specific credentials. Confused? Good!

#### Using STS

You can also configure this plugin to use [AWS STS](https://docs.aws.amazon.com/STS/latest/APIReference/Welcome.html) to "assume" a role that has access to Kinesis and CloudWatch. If you use this in combination with EC2 instance profiles (which the defaults credentials provider explained above uses) then you can actually configure your Logstash to write to Kinesis and CloudWatch without any hardcoded credentials.

```nginx
output {
  kinesis {
    # ...

    role_arn => "arn:aws:iam::123456789:role/my-kinesis-producer-role"

    # You can also provide a specific role to assume for CloudWatch metrics:
    metrics_role_arn => "arn:aws:iam::123456789:role/my-metrics-role"
  }
}
```

You can combine `role_arn` / `metrics_role_arn` with the explicit AWS credentials config explained earlier, too.

All this stuff can be mixed too - if you wanted to use hardcoded credentials for Kinesis, but then assume a role via STS for accessing CloudWatch, you can do that. Vice versa would work too - assume a role for accessing Kinesis and then providing hardcoded credentials for CloudWatch. Make things as arbitrarily complicated for yourself as you like ;)

### Building a partition key

Kinesis demands a [partition key](https://docs.aws.amazon.com/kinesis/latest/dev/key-concepts.html#partition-key) be provided for each record. By default, this plugin will provide a very boring partition key of `-`. However, you can configure it to compute a partition key from fields in your log events.

```nginx
output {
  kinesis {
    # ...
    event_partition_keys => ["[field1]", "[field2]"]
  }
}
```

### Record Aggregation

The [Amazon KPL library can aggregate](https://docs.aws.amazon.com/kinesis/latest/dev/kinesis-kpl-concepts.html#d0e3423) your records when writing to the Kinesis stream. **This behaviour is configured to be enabled by default.**

If you are using an older version of the Amazon KCL library to consume your records, or not using KCL at all, your consumer application(s) will probably not behave correctly. See [the matrix on this page](https://docs.aws.amazon.com/kinesis/latest/dev/kinesis-kpl-integration.html) for more info, and read [more about de-aggregating records here](https://docs.aws.amazon.com/kinesis/latest/dev/kinesis-kpl-consumer-deaggregation.html).

If you wish to simply disable record aggregation, that's easy:

```nginx
output {
  kinesis {
    aggregation_enabled => false
  }
}
```


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

### Noisy warnings about `Error during socket read`

While your Logstash instance is running, you may occasionally get a warning on stderr that looks like this:

```
[2015-10-20 06:31:08.441640] [0x00007f36c9402700] [error] [io_service_socket.h:229] Error during socket read: End of file; 0 bytes read so far (kinesis.us-west-1.amazonaws.com:443)
```

This is being tracked in [amazon-kinesis-producer#17](https://github.com/awslabs/amazon-kinesis-producer/issues/17). This log message seems to just be noise - your logs should still be delivering to Kinesis fine (but of course, you should independently verify this!).


## Developing

Ensure you have JRuby 1.7.x installed. [rvm](https://rvm.io/) is your friend :)

```sh
bundle install
bundle exec rake
```

### Updating KPL

Change the dependency version in `build.gradle`, and then run `gradle copylibs`. Make sure to check in all the updated JARs! Yes, we put them in the repo :(


## Contributions

Are more than welcome. Raising an issue is great, raising a PR is better, raising a PR with tests is best.


## License

[Apache License 2.0](LICENSE)

[travis]: https://travis-ci.org/samcday/logstash-output-kinesis
[rubygems]: https://rubygems.org/gems/logstash-output-kinesis
[kpldoc]: https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.1/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L38

[badge-travis]: https://img.shields.io/travis/samcday/logstash-output-kinesis.svg?style=flat-square
[badge-gem]: https://img.shields.io/gem/v/logstash-output-kinesis.svg?style=flat-square
