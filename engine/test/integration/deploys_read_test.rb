require "test_helper"

class DeploysReadTest < ActionDispatch::IntegrationTest
  WRITE_SECRET = "test-secret-123"

  setup do
    Crumb.config.ingest_secret = WRITE_SECRET
    Crumb::Deploy.delete_all
    Crumb::DeployCommit.delete_all
    Crumb::DeployChangedFile.delete_all
    Crumb::AccessToken.delete_all

    @deploy = Crumb::Deploy.create!(
      sha: "abc123", previous_sha: "def456", branch: "main", author: "nico",
      kind: "deploy", status: "success", started_at: 1.hour.ago, finished_at: 55.minutes.ago,
      duration_seconds: 300
    )
    Crumb::DeployCommit.create!(
      crumb_deploy_id: @deploy.id, sha: "c1", author: "nico@test.com",
      message: "Fix bug", committed_at: 2.hours.ago
    )
    Crumb::DeployChangedFile.create!(
      crumb_deploy_id: @deploy.id, path: "app/models/order.rb", change_type: "M"
    )

    raw = SecureRandom.hex(32)
    @raw_token = raw
    Crumb::AccessToken.create!(owner: "nico@test.com",
                                token_digest: Digest::SHA256.hexdigest(raw))
  end

  # --- GET /crumb/deploys ---

  test "lists recent successful deploys with a read token" do
    get "/crumb/deploys", headers: read_headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["deploys"].length
    d = body["deploys"].first
    assert_equal "abc123", d["sha"]
    assert_equal 1, d["commit_count"]
    assert_equal 1, d["changed_file_count"]
  end

  test "filters by touching path prefix" do
    get "/crumb/deploys?touching=app/models/order", headers: read_headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["deploys"].length
  end

  test "touching filter returns empty when no match" do
    get "/crumb/deploys?touching=app/services/", headers: read_headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert_empty body["deploys"]
  end

  test "write secret also grants read access to GET /deploys" do
    get "/crumb/deploys", headers: write_headers

    assert_response :ok
  end

  test "returns 401 on missing auth for GET /deploys" do
    get "/crumb/deploys", headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  # --- GET /crumb/deploys/:id ---

  test "returns full deploy detail with commits and changed files" do
    get "/crumb/deploys/#{@deploy.id}", headers: read_headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "abc123", body["sha"]
    assert_equal 1, body["commits"].length
    assert_equal "Fix bug", body["commits"].first["message"]
    assert_equal 1, body["changed_files"].length
    assert_equal "app/models/order.rb", body["changed_files"].first["path"]
  end

  test "returns 401 on bad token for GET /deploys/:id" do
    get "/crumb/deploys/#{@deploy.id}",
      headers: { "Authorization" => "Bearer bad-token", "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def read_headers
    { "Authorization" => "Bearer #{@raw_token}", "Accept" => "application/json" }
  end

  def write_headers
    { "Authorization" => "Bearer #{WRITE_SECRET}", "Accept" => "application/json" }
  end
end
