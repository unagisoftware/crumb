module Crumb
  module MCP
    module Tools
      class CompareDeploysTool < ::MCP::Tool
        tool_name "compare_deploys"
        description "Union of commits and changed files between two deploys on the same endpoint."
        input_schema(
          properties: {
            endpoint: { type: "string",  description: "Endpoint slug." },
            from_id:  { type: "integer", description: "Older deploy ID." },
            to_id:    { type: "integer", description: "Newer deploy ID." }
          },
          required: [ "endpoint", "from_id", "to_id" ]
        )

        class << self
          def call(endpoint:, from_id:, to_id:, server_context: nil)
            client = ApiClient.for(endpoint)
            from   = client.detail(from_id)
            to     = client.detail(to_id)

            all_commits = (Array(from["commits"]) + Array(to["commits"]))
              .uniq { |c| c["sha"] }
            all_files   = (Array(from["changed_files"]) + Array(to["changed_files"]))
              .uniq { |f| f["path"] }

            text = "Comparison between deploy ##{from_id} and ##{to_id} on #{endpoint}\n\n"
            text += "Commits (#{all_commits.size} unique):\n"
            all_commits.each { |c| text += "  #{c["sha"][0, 8]} #{c["author"]} — #{c["message"]}\n" }
            text += "\nChanged files (#{all_files.size} unique):\n"
            all_files.each { |f| text += "  #{f["change_type"]} #{f["path"]}\n" }

            ::MCP::Tool::Response.new([ { type: "text", text: text } ])
          end
        end
      end
    end
  end
end
