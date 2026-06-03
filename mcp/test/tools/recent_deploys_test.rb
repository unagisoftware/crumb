require "test_helper"

class RecentDeploysToolTest < Minitest::Test
  FakeClient = Struct.new(:deploys) do
    def recent(limit: 20) = deploys
  end

  def fake_deploy(slug, sha: "abc123def456", author: "nico")
    {
      "endpoint"           => slug,
      "id"                 => 1,
      "sha"                => sha,
      "branch"             => "main",
      "author"             => author,
      "status"             => "success",
      "kind"               => "deploy",
      "finished_at"        => "2026-06-01T10:00:00Z",
      "duration_seconds"   => 120,
      "commit_count"       => 3,
      "changed_file_count" => 7
    }
  end

  def test_fans_out_across_all_endpoints_when_no_endpoint_given
    clients = {
      "app-a" => FakeClient.new([ fake_deploy("app-a") ]),
      "app-b" => FakeClient.new([ fake_deploy("app-b", sha: "fffeeeddccbb") ])
    }
    stub_method(Crumb::MCP::Registry, :all_slugs, %w[app-a app-b]) do
      stub_method(Crumb::MCP::ApiClient, :for, ->(slug) { clients[slug] }) do
        result = Crumb::MCP::Tools::RecentDeploysTool.call
        text   = result.content.first[:text]
        assert_match "[app-a]", text
        assert_match "[app-b]", text
      end
    end
  end

  def test_queries_single_endpoint_when_specified
    client = FakeClient.new([ fake_deploy("my-app") ])
    stub_method(Crumb::MCP::ApiClient, :for, client) do
      result = Crumb::MCP::Tools::RecentDeploysTool.call(endpoint: "my-app")
      text   = result.content.first[:text]
      assert_match "[my-app]", text
      assert_match "abc123de", text
      assert_match "#1", text # deploy id, needed to chain into deploy_details
    end
  end

  def test_returns_message_when_no_deploys_found
    stub_method(Crumb::MCP::Registry, :all_slugs, %w[my-app]) do
      stub_method(Crumb::MCP::ApiClient, :for, FakeClient.new([])) do
        result = Crumb::MCP::Tools::RecentDeploysTool.call
        assert_match "No deployments found", result.content.first[:text]
      end
    end
  end
end
