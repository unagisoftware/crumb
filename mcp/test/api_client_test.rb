require "test_helper"

class ApiClientTest < Minitest::Test
  BASE = "https://app.example/crumb"
  TOKEN = "test-token"

  def client
    Crumb::MCP::ApiClient.new(BASE, TOKEN, nil, "my-app")
  end

  def test_recent_sends_correct_auth_header
    stub_request(:get, "#{BASE}/deploys?limit=20")
      .with(headers: { "Authorization" => "Bearer #{TOKEN}" })
      .to_return(status: 200, body: { deploys: [] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    result = client.recent
    assert_equal [], result
  end

  def test_recent_tags_deploys_with_endpoint_slug
    stub_request(:get, "#{BASE}/deploys?limit=5")
      .to_return(status: 200,
                 body: { deploys: [ { "id" => 1, "sha" => "abc" } ] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    result = client.recent(limit: 5)
    assert_equal "my-app", result.first["endpoint"]
  end

  def test_detail_fetches_single_deploy
    stub_request(:get, "#{BASE}/deploys/42")
      .to_return(status: 200,
                 body: { "id" => 42, "sha" => "abc123" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    result = client.detail(42)
    assert_equal 42,       result["id"]
    assert_equal "my-app", result["endpoint"]
  end

  def test_touching_sends_path_param
    stub_request(:get, "#{BASE}/deploys?touching=app%2Fmodels&limit=20")
      .to_return(status: 200, body: { deploys: [] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    result = client.touching("app/models")
    assert_equal [], result
  end

  def test_raises_on_non_200
    stub_request(:get, "#{BASE}/deploys?limit=20")
      .to_return(status: 401, body: "Unauthorized")

    assert_raises(Crumb::MCP::ApiClient::Error) { client.recent }
  end
end
