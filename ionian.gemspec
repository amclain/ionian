version = File.read(File.expand_path('../version', __FILE__)).strip

Gem::Specification.new do |s|
  s.name      = 'ionian'
  s.version   = version
  s.date      = Time.now.strftime '%Y-%m-%d'
  s.summary   = 'Regular expression matching and notification for IO streams.'
  s.description =
  "A library to simplify interaction with IO streams. This includes network sockets, file sockets, and serial streams like the console and RS232. Features regular expression matching and notification of received data."
  
  s.homepage  = 'https://bitbucket.org/amclain/ionian'
  s.authors   = ['Alex McLain']
  s.email     = 'alex@alexmclain.com'
  s.license   = 'MIT'
  
  s.files     =
    ['license.txt'] +
    # Dir['bin/**/*'] +
    Dir['lib/**/*'] +
    Dir['doc/**/*']
  
  s.executables = [
  ]
  
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec'
end
