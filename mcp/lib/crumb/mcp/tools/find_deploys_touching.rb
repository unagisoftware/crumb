module Crumb
  module MCP
    module Tools
      class FindDeploysTouchingTool < ::MCP::Tool
        tool_name "find_deploys_touching"
        description "Find deploys that touched files matching a path prefix. Fast via indexed DB query."
        input_schema(
          properties: {
            path_prefix: { type: "string",  description: "Path prefix to match (e.g. 'app/models/order')." },
            endpoint:    { type: "string",  description: "Endpoint slug. Omit to query all endpoints." },
            limit:       { type: "integer", description: "Max results per endpoint (default 20)." }
          },
          required: [ "path_prefix" ]
        )

        class << self
          def call(path_prefix:, endpoint: nil, limit: 20, server_context: nil)
            slugs   = endpoint ? [ endpoint ] : Registry.all_slugs
            deploys = []
            errors  = []

            slugs.each do |slug|
              deploys.concat(ApiClient.for(slug).touching(path_prefix, limit: limit))
            rescue => e
              errors << "[#{slug}] error: #{e.message}"
            end

            deploys.sort_by! { |d| d["finished_at"].to_s }.reverse!

            text =
              if deploys.empty?
                "No deploys found touching '#{path_prefix}'."
              else
                "Deploys touching '#{path_prefix}':\n\n" + deploys.map do |d|
                  "[#{d["endpoint"]}] ##{d["id"]} #{d["sha"][0, 8]} by #{d["author"]} on #{d["finished_at"]}"
                end.join("\n")
              end
            text += "\n\n" + errors.join("\n") unless errors.empty?

            ::MCP::Tool::Response.new([ { type: "text", text: text } ])
          end
        end
      end
    end
  end
end
