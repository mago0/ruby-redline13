#!/usr/bin/env ruby

# This example will run a JMeter test on Redline13
# It will initiate the test and then wait for completion and output files.
# Once the files are available, it will download them and merge the results.
#
# This example also assumes the the gem has been installed via bundler

base_path = File.expand_path('../', File.dirname(__FILE__))
require 'rubygems'
require 'bundler/setup'
require 'redline13'

timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')

settings = Hash.new
%w{ api_key aws_keypair_id jmx_file test_name srv_cnt dry_run }.each do |name|
  if (!settings[name] = ENV["REDLINE_#{name.upcase}"])
    puts "REDLINE_#{name.upcase} Environment Variable Must be Set"
    exit 1
  end
end
dry_run = (settings['dry_run'].downcase == 'true') ? true : false
# Uncomment following lines to run a Ubik based test
#ubik_plugin_enabled = true
#ubik_license = "#{base_path}/ubik-plugin.license"

# Uncomment line to just see test parameters that will be passed to the API 
#dry_run = true

servers = [{
  'location' => 'us-east-1',
  'subnetId' => 'subnet-xyz',
  'associatePublicIpAddress' => 'T',
  'size' => 'm4.xlarge',
  'num' => 2,
  'onDemand' => 'T'
}]

jvm_args = [ '-Xmx15000m' ] # Appropriate for m4.xlarge

jmeter_opts = { 'threads' => 100, 'rampup' => 60 }

test = Redline13::JMeter.new(redline_key,
                             aws_keypair_id,
                             test_name,
                             jmx_file,
                             servers,
                             jvm_args,
                             jmeter_opts,
                             ubik_plugin_enabled,
                             ubik_license,
                             dry_run)

# Print all test params as passed to the Redline13 API
puts test
exit if dry_run

test_id = test.getTestId
results_path = "#{base_path}/results/#{test_id}"

while (!test.getStarted) do puts "Waiting for test to start."; sleep 30 end
puts "Started: ", test.getStarted

while (!test.getCompleted) do puts "Waiting for test to complete."; sleep 30 end
puts "Completed: ", test.getCompleted

while (!test.getOutputFiles) do puts "Waiting for output files."; sleep 30 end
files = test.getOutputFiles

puts "Files ready. Downloading."
`mkdir -p #{results_path} || true && rm -rf #{results_path}/*`
cnt = 0
files.each do |file|
  output_file = "#{results_path}/server_#{cnt}.tgz"
  puts "Downloading and extracting: #{output_file}"
  system(<<-EOS
    set -e
    wget -o /dev/null -O #{output_file} '#{file['url']}'
    tar -zxf #{output_file} -C #{results_path}
    mv #{results_path}/output/runLoadTest.jtl #{results_path}/server_#{cnt}.jtl
    rm -rf #{results_path}/output #{results_path}/logs
    EOS
  )
  cnt += 1
end

puts "Merging results and generating report."
system(<<-EOS
  set -e
  mkdir #{results_path}/server_files
  mv #{results_path}/*.tgz #{results_path}/server_files
  mv #{results_path}/server_0.jtl #{results_path}/results.csv
  tail -q -n +2 #{results_path}/server_*.jtl >>#{results_path}/results.csv && rm -f #{results_path}/server_*.jtl
  /usr/local/bin/jmeter -g #{results_path}/results.csv -o #{results_path}/report
  EOS
)
