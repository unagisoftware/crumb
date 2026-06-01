require "test_helper"

class DeploysWriteTest < ActionDispatch::IntegrationTest
  WRITE_SECRET = "test-secret-123"

  setup do
    Crumb.config.ingest_secret = WRITE_SECRET
    Crumb::Deploy.delete_all
    Crumb::DeployCommit.delete_all
    Crumb::DeployChangedFile.delete_all
    Crumb::AccessToken.delete_all
  end

  # --- POST /crumb/deploys ---

  test "creates a running deploy and returns deploy_id with nil previous_sha on first deploy" do
    post "/crumb/deploys",
      params: { sha: "abc123", branch: "main", author: "nico", started_at: "2026-06-01T10:00:00Z" }.to_json,
      headers: write_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert body["deploy_id"].present?
    assert_nil body["previous_sha"].presence

    deploy = Crumb::Deploy.find(body["deploy_id"])
    assert_equal "running", deploy.status
    assert_equal "abc123",  deploy.sha
  end

  test "returns previous_sha from the last successful deploy" do
    first = Crumb::Deploy.create!(sha: "def456", status: "success", kind: "deploy",
                                   finished_at: 1.hour.ago)

    post "/crumb/deploys",
      params: { sha: "abc123", branch: "main", author: "nico", started_at: "2026-06-01T10:00:00Z" }.to_json,
      headers: write_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "def456", body["previous_sha"]
  end

  test "marks stale running deploys as failed on new POST" do
    stale = Crumb::Deploy.create!(sha: "stale123", status: "running", kind: "deploy",
                                   started_at: 2.hours.ago)

    post "/crumb/deploys",
      params: { sha: "abc123", branch: "main", author: "nico", started_at: "2026-06-01T10:00:00Z" }.to_json,
      headers: write_headers

    assert_response :created
    assert_equal "failed", stale.reload.status
  end

  test "returns 401 on missing auth for POST" do
    post "/crumb/deploys",
      params: { sha: "abc123" }.to_json,
      headers: json_headers

    assert_response :unauthorized
  end

  test "returns 401 on wrong secret for POST" do
    post "/crumb/deploys",
      params: { sha: "abc123" }.to_json,
      headers: json_headers.merge("Authorization" => "Bearer wrong-secret")

    assert_response :unauthorized
  end

  # --- PATCH /crumb/deploys/:id ---

  test "closes a deploy with kind=deploy, commits, and changed files" do
    deploy = Crumb::Deploy.create!(sha: "abc123", previous_sha: "def456",
                                    status: "running", kind: "deploy", started_at: 1.minute.ago)

    patch "/crumb/deploys/#{deploy.id}",
      params: {
        status:           "success",
        kind:             "deploy",
        finished_at:      "2026-06-01T10:03:00Z",
        duration_seconds: 180,
        commits: [
          { sha: "c1", author: "nico@test.com", message: "Add thing", committed_at: "2026-06-01T09:00:00Z" }
        ],
        changed_files: [
          { path: "app/models/thing.rb", change_type: "A" }
        ],
        metadata: { kamal_command: "deploy" }
      }.to_json,
      headers: write_headers

    assert_response :ok
    deploy.reload
    assert_equal "success", deploy.status
    assert_equal "deploy",  deploy.kind
    assert_equal 180,       deploy.duration_seconds
    assert_equal 1,         deploy.deploy_commits.count
    assert_equal 1,         deploy.deploy_changed_files.count
    assert_equal "app/models/thing.rb", deploy.deploy_changed_files.first.path
  end

  test "resolves reverts_deploy_id for rollbacks" do
    original = Crumb::Deploy.create!(sha: "def456", status: "success", kind: "deploy",
                                      finished_at: 1.hour.ago)
    rollback_deploy = Crumb::Deploy.create!(sha: "abc123", previous_sha: "def456",
                                             status: "running", kind: "deploy", started_at: 1.minute.ago)

    patch "/crumb/deploys/#{rollback_deploy.id}",
      params: {
        status: "success", kind: "rollback", finished_at: "2026-06-01T10:01:00Z",
        duration_seconds: 30, commits: [], changed_files: [], metadata: {}
      }.to_json,
      headers: write_headers

    assert_response :ok
    rollback_deploy.reload
    assert_equal "rollback",    rollback_deploy.kind
    assert_equal original.id,  rollback_deploy.reverts_deploy_id
  end

  test "returns 401 on wrong secret for PATCH" do
    deploy = Crumb::Deploy.create!(sha: "abc123", status: "running", kind: "deploy",
                                    started_at: 1.minute.ago)

    patch "/crumb/deploys/#{deploy.id}",
      params: { status: "success" }.to_json,
      headers: json_headers.merge("Authorization" => "Bearer wrong")

    assert_response :unauthorized
  end

  private

  def write_headers
    json_headers.merge("Authorization" => "Bearer #{WRITE_SECRET}")
  end

  def json_headers
    { "Content-Type" => "application/json", "Accept" => "application/json" }
  end
end
