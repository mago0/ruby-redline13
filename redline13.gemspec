Gem::Specification.new do |s|
  s.name        = 'redline13'
  s.version     = '0.3.1'
  s.date        = '2017-06-21'
  s.summary     = "Interface to Redline13 API"
  s.description = "Currently supports the execution of a JMeter load-test"
  s.authors     = ["Matt Williams"]
  s.email       = 'matt@williams-tech.net'
  s.files       = ["lib/redline13.rb"]
  s.homepage    =
    'https://github.com/mago0/ruby-redline13'
  s.license       = 'MIT'

  s.add_runtime_dependency 'json', '~> 2.0'
  s.add_runtime_dependency 'rest-client', '~> 2.0' 
end
