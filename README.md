# ruby-redline13
Ruby gem for launching JMeter tests on Redline13. Support for additional test
types may be added in future releases.

## Installation with Bundler
Append to Gemfile:

`gem 'redline13', :git => 'git@github.com:mago0/ruby-redline13.git'`

Install

`bundle install`

## Basic Usage:
```
require 'redline13'

test = Redline13::JMeter.new(redline_key,
                             aws_keypair_id,
                             test_name,
                             path_to_test_file,
                             servers,
                             jvm_args,
                             jmeter_opts,
                             ubik_plugin_enabled,
                             ubik_license,
                             dry_run)
```

Reference **doc/Redline13/JMeter.html** for a full explanation of parameters and
class methods.

[Example Script](example.rb)
