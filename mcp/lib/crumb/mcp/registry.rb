require "yaml"

module Crumb
  module MCP
    class Registry
      CONFIG_PATH = File.expand_path("~/.config/crumb/config.yml")

      class << self
        def all_slugs
          config["endpoints"].keys
        end

        def endpoint_for(slug)
          ep = config["endpoints"][slug]
          raise ArgumentError, "Unknown Crumb endpoint: #{slug}" unless ep
          {
            base_url:  ep["base_url"],
            token_env: ep["token_env"],
            repo_path: ep["repo_path"] && File.expand_path(ep["repo_path"])
          }
        end

        private

        def config
          @config ||= begin
            raise "Crumb config not found at #{CONFIG_PATH}" unless File.exist?(CONFIG_PATH)
            YAML.safe_load_file(CONFIG_PATH)
          end
        end
      end
    end
  end
end
