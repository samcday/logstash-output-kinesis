## TL;DR

Raising an issue is great, raising a PR is better, raising a PR with tests is *bestest*.

## Developing

You'll need [Git LFS](https://git-lfs.github.com/) to properly clone this repo.

Ensure you have JRuby 9.1.x installed. [rvm](https://rvm.io/) is your friend :)

```sh
rvm use --install .
gem install bundler && bundle install
bundle exec rake
```

### Running tests

```
rake
```

### Building gem

```
gem build logstash-output-kinesis
```

### Testing locally built gem
```
bin/logstash-plugin install --local /path/to/logstash-output-kinesis-5.1.1-java.gem
```

### Updating KPL

Change the dependency version in `build.gradle`, and then run `gradle copylibs`. Make sure to check in all the updated JARs!
