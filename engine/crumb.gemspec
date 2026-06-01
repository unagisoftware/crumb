require_relative "lib/crumb/version"

Gem::Specification.new do |spec|
  spec.name        = "crumb"
  spec.version     = Crumb::VERSION
  spec.authors     = [ "Nico Galdamez" ]
  spec.email       = [ "nicogaldamez@gmail.com" ]
  spec.homepage    = "https://github.com/nicogaldamez/crumb"
  spec.summary     = "Deployment observability Rails engine for Crumb."
  spec.description = "Mountable Rails engine that records deploy history and exposes a read API for the crumb-mcp server."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "pg", ">= 1.0"
end
