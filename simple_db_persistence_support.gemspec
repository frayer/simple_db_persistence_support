require 'date'

Gem::Specification.new do |gem|
  gem.name    = "simple_db_persistence_support"
  gem.version = "0.0.1"
  gem.date    = Date.today.to_s

  gem.summary = "Small Ruby Module which can be included into a class to provide simple persistance capabilities against Amazon SimpleDB."
  gem.description = ""
  gem.homepage = "http://www.frayer.org/"

  gem.authors  = ["Michael Frayer"]
  gem.email    = "mrfrayer@yahoo.com"

  gem.files = Dir['Rakefile', '{bin,lib,man,test,spec}/**/*', 'README*', 'LICENSE*']
end
