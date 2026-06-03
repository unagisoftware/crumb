module Crumb
  module MCP
    module Tools
      class RecentDeploysTool < ::MCP::Tool
        tool_name "recent_deploys"
        description "List recent deployments. Omit `endpoint` to query all configured endpoints."
        input_schema(
          properties: {
            endpoint: { type: "string", description: "Endpoint slug (e.g. my-app). Omit for all." },
            limit:    { type: "integer", description: "Max results per endpoint (default 20)." }
          }
        )

        class << self
          def call(endpoint: nil, limit: 20, server_context: nil)
            slugs   = endpoint ? [ endpoint ] : Registry.all_slugs
            deploys = slugs.flat_map { |slug| ApiClient.for(slug).recent(limit: limit) }
            deploys.sort_by! { |d| d["finished_at"].to_s }.reverse!
            ::MCP::Tool::Response.new([ { type: "text", text: format_deploys(deploys) } ])
          end

          private

          def format_deploys(deploys)
            return "No deployments found." if deploys.empty?
            deploys.map do |d|
              "[#{d["endpoint"]}] ##{d["id"]} #{d["sha"][0, 8]} — #{d["branch"]} by #{d["author"]} " \
                "(#{d["status"]}, #{d["duration_seconds"]}s) #{d["finished_at"]} " \
                "[#{d["commit_count"]} commits, #{d["changed_file_count"]} files]"
            end.join("\n")
          end
        end
      end
    end
  end
end
