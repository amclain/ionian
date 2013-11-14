version = File.read(File.expand_path('../version', __FILE__)).strip

Gem::Specification.new do |s|
  s.name      = 'ionian'
  s.version   = version
  s.date      = Time.now.strftime '%Y-%m-%d'
  s.summary   = 'Regular expression matching and notification for IO.'
  s.description =
  "A mixin for IO objects that allows regular expression matching and convenient notification of data in the buffer."
  
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
  s.add_development_dependency 'minitest'
end
