require 'rspec/core/rake_task'
require 'rdoc/task'

task :default => [:test]

# Run tests.
RSpec::Core::RakeTask.new(:test)

# Build the gem.
task :build => [:doc] do
  # system 'markup README.md --force'
  
  Dir['*.gem'].each {|file| File.delete file}
  system 'gem build *.gemspec'
end

# Rebuild and [re]install the gem.
task :install => [:build] do
  system 'gem install *.gem'
end

# Generate documentation.
RDoc::Task.new :doc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.include 'lib/**/*.rb'
end
