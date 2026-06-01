require_relative "lib/crumb/mcp/version"

Gem::Specification.new do |spec|
  spec.name        = "crumb-mcp"
  spec.version     = Crumb::MCP::VERSION
  spec.authors     = [ "Nico Galdamez" ]
  spec.email       = [ "nicogaldamez@gmail.com" ]
  spec.homepage    = "https://github.com/nicogaldamez/crumb"
  spec.summary     = "MCP server for Crumb deployment observability."
  spec.description = "Standalone MCP server that federates across Crumb-enabled endpoints and exposes deploy history as LLM tools."
  spec.license     = "MIT"

  spec.files         = Dir["{lib,exe}/**/*"]
  spec.bindir        = "exe"
  spec.executables   = [ "crumb-mcp" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "mcp",    ">= 0.8.0"
  spec.add_dependency "faraday", ">= 2.0"
end
