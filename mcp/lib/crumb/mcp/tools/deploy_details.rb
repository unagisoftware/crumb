module Crumb
  module MCP
    module Tools
      class DeployDetailsTool < ::MCP::Tool
        tool_name "deploy_details"
        description "Full detail for one deploy: commits, changed files, and optionally the git diff."
        input_schema(
          properties: {
            endpoint:     { type: "string",  description: "Endpoint slug (required)." },
            id:           { type: "integer", description: "Deploy ID." },
            include_diff: { type: "boolean", description: "Include git diff output (slow)." }
          },
          required: [ "endpoint", "id" ]
        )

        class << self
          def call(endpoint:, id:, include_diff: false, server_context: nil)
            client = ApiClient.for(endpoint)
            deploy = client.detail(id)
            text   = format_detail(deploy)
            text  += "\n\n" + client.diff(deploy["sha"]) if include_diff
            ::MCP::Tool::Response.new([ { type: "text", text: text } ])
          end

          private

          def format_detail(d)
            lines = []
            lines << "Deploy #{d["id"]} on #{d["endpoint"]}"
            lines << "SHA:      #{d["sha"]} (prev: #{d["previous_sha"]})"
            lines << "Branch:   #{d["branch"]}  Author: #{d["author"]}"
            lines << "Status:   #{d["status"]}  Kind: #{d["kind"]}"
            lines << "Time:     #{d["started_at"]} → #{d["finished_at"]} (#{d["duration_seconds"]}s)"
            lines << "Reverts:  deploy ##{d["reverts_deploy_id"]}" if d["reverts_deploy_id"]
            lines << ""
            lines << "Commits (#{Array(d["commits"]).size}):"
            Array(d["commits"]).each do |c|
              lines << "  #{c["sha"].to_s[0, 8]} #{c["author"]} — #{c["message"]}"
            end
            lines << ""
            lines << "Changed files (#{Array(d["changed_files"]).size}):"
            Array(d["changed_files"]).each do |f|
              lines << "  #{f["change_type"]} #{f["path"]}"
            end
            lines.join("\n")
          end
        end
      end
    end
  end
end
