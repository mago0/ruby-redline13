#!/usr/bin/env ruby
require 'json'
require 'pp'
require 'rest-client'

module Redline13

# This class creates a Redline13 Jmeter test and provides methods for
# checking status and retrieving output of the test upon completion.

class JMeter

  API_URL = 'https://www.redline13.com/Api'
  DEFAULT_JVM_ARGS = [
    '-Djava.net.preferIPv4Stack=true',
    '-Djava.net.preferIPv6Addresses=false',
  ]
  DEFAULT_JM_OPTS = {}
  DEFAULT_TEST_PARAMS = {
    'testType' => 'jmeter-test',
    'storeOutput' => 'T',
    'version' => '3.1',
    'plugin[0]' => 'standard',
    'plugin[1]' => 'extras',
    'plugin[2]' => 'extraswithlibs',
  }

  # Instantiation of this class results in a new load test.
  #
  # ==Required Parameters:
  # [key]                 Redline13 API Key
  # [aws_keypair_id]      The AWS keypair_id assigned to Redline13
  # [name]                Name of the test
  # [file]                Jmeter test file
  # [servers]             Array of server definitions.
  # Example:
  #  [{ 'location'                  => 'us-west-2',
  #     'subnetId'                  => 'subnet-xyz',
  #     'associatePublicIpAddress'  => 'T',
  #     'size'                      => 'm4.xlarge',
  #     'num'                       => 1,
  #     'onDemand'                  => 'T' }]
  # All of the above parameters are required
  #
  # ==Optional Parameters:
  # [csv_file]            Path to any additonal test files
  # [jvm_args]            Array of JVM arguments 
  # [jmeter_opts]         Hash of Jmeter arguments
  # [ubik_stream_plugin]  Set true to enable plugin. default: false
  # [ubik_license_file]   Path to ubik license file (if enabled)
  # [dry_run]             Set false to execute test. default: true 
  def initialize(key, aws_keypair_id, name, file, servers,
                 csv_file = nil, jvm_args = [], jmeter_opts = {},
                 ubik_stream_plugin = false, ubik_license_file = nil,
                 dry_run = true)

    @client = RestClient::Resource.new(
      API_URL,
      'headers': {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Redline-Auth': key
      }
    )
    @server_cnt = 0
    servers.each { |server| @server_cnt += server['num'] }
    formatted_servers = Hash.new 
    iteration = 0
    servers.each do |server|
      server.each { |k,v| formatted_servers["servers[#{iteration}][#{k}]"] = v }
      # Set manually because this doesn't matter for JMeter tests
      formatted_servers["servers[#{iteration}][usersPerServer]"] = 1
      iteration += 1
    end
    test_params = {
      'key' => key,
      'key_pair_id' => aws_keypair_id,
      'name' => name,
      'file' => File.new(file, "rb"),
      'numServers' => @server_cnt
    }.merge(DEFAULT_TEST_PARAMS).merge(formatted_servers)
    if (!jvm_args.empty?)
      test_params['jvm_args'] = (jvm_args + DEFAULT_JVM_ARGS).join(' ').to_s.strip
    end
    if (!jmeter_opts.empty?)
      test_params['opts'] = jmeter_opts.merge(DEFAULT_JM_OPTS).map do |k,v| 
        "-J#{k}='#{v}'"
      end.join(' ').to_s.strip
    end
    if (ubik_stream_plugin && ubik_license_file) 
      ubik_license = File.open(ubik_license_file, "rb") { |file| file.read }
      test_params.merge!({
        'ulp_hls_player.max_connections_per_client' => '500',
        'plugin[3]' => 'ubikstream', 
        'jmeter-ubikstream-license' => ubik_license
      })
    end
    if (csv_file)
      test_params.merge!({ 'extras[]' => File.new(csv_file, "rb") })
    end

    @test_params = test_params
    @ubik_stream_plugin = ubik_stream_plugin
    @dry_run = dry_run

    if (dry_run)
      @test_id = nil
    else
      @test_id = JSON.parse(@client['/LoadTest'].post(test_params))['loadTestId'] || nil
    end
  end

  # Returns test start time. Returns nil if dry_run or test not yet started
  def getStarted
    if @dry_run
      nil
    else
      JSON.parse(@client["/LoadTest?loadTestId=#{@test_id}"].get)[0].to_h['start_time']
    end
  end

  # Returns test completed time. Returns nil if dry_run or test not yet completed.
  def getCompleted
    if @dry_run
      nil
    else
      JSON.parse(@client["/LoadTest?loadTestId=#{@test_id}"].get)[0].to_h['completed_time']
    end
  end
 
  # Returns list of output files. Returns nil if test not completed or output
  # file number doesn't match server_cnt
  def getOutputFiles
    if (self.getCompleted)
      file_list = JSON.parse(@client["/StatsDownloadUrls?loadTestId=#{@test_id}"].get)['outputFiles']
      if (file_list && file_list.length == @server_cnt)
        file_list
      end
    end
  end

  # Returns full test status from Redline13
  def getFullStatus
    JSON.parse(@client["/LoadTest?loadTestId=#{@test_id}"].get)[0].to_h
  end

  # Returns full definition of parameters for API call
  def to_s
    test_params = @ubik_stream_plugin ? test_params.merge({ 'jmeter-ubikstream-license' => 'TRUNCATED' }) : @test_params
    "Test Parameters:\n#{test_params.pretty_inspect}\nTestID: #{@test_id ? @test_id : 'nil'}" 
  end 

  # Returns test ID. Returns nil if dry_run or API error.
  def getTestId
    @test_id
  end

end # JMeter Class

end
