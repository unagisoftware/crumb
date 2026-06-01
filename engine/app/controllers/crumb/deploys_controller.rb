module Crumb
  class DeploysController < ApplicationController
    before_action :require_write_secret!, only: [ :create, :update ]

    def index
      scope = Deploy.recent_successes.limit(params[:limit] || 20)

      if params[:touching].present?
        scope = scope
          .joins(:deploy_changed_files)
          .where("crumb_deploy_changed_files.path LIKE ?", "#{params[:touching]}%")
          .distinct
      end

      render json: { deploys: scope.map { |d| list_attrs(d) } }
    end

    def show
      deploy = Deploy.find(params[:id])
      render json: detail_attrs(deploy)
    end

    def create
      result = nil

      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute(
          "SELECT pg_advisory_xact_lock(hashtext('crumb_deploy_create'))"
        )

        Deploy.where(status: "running").update_all(status: "failed")

        previous = Deploy.where(status: "success").order(finished_at: :desc).first
        previous_sha = previous&.sha

        result = Deploy.create!(
          sha:          params[:sha],
          branch:       params[:branch],
          author:       params[:author],
          started_at:   params[:started_at],
          previous_sha: previous_sha,
          status:       "running",
          kind:         "deploy"
        )
      end

      render json: { deploy_id: result.id, previous_sha: result.previous_sha }, status: :created
    end

    def update
      deploy = Deploy.find(params[:id])

      kind   = params[:kind].presence || "deploy"
      status = params[:status].presence || "success"

      if kind == "rollback"
        reverts = Deploy.where(sha: deploy.previous_sha).order(id: :desc).first
        deploy.reverts_deploy_id = reverts&.id
      end

      deploy.update!(
        kind:             kind,
        status:           status,
        finished_at:      params[:finished_at],
        duration_seconds: params[:duration_seconds],
        metadata:         params[:metadata] || {}
      )

      if params[:commits].present?
        commit_rows = Array(params[:commits]).map do |c|
          {
            crumb_deploy_id: deploy.id,
            sha:             c[:sha],
            author:          c[:author],
            message:         c[:message],
            committed_at:    c[:committed_at]
          }
        end
        DeployCommit.insert_all(commit_rows) if commit_rows.any?
      end

      if params[:changed_files].present?
        file_rows = Array(params[:changed_files]).map do |f|
          {
            crumb_deploy_id: deploy.id,
            path:            f[:path],
            change_type:     f[:change_type]
          }
        end
        DeployChangedFile.insert_all(file_rows) if file_rows.any?
      end

      render json: { id: deploy.id, status: deploy.status }
    end

    private

    def list_attrs(d)
      {
        id:                 d.id,
        sha:                d.sha,
        previous_sha:       d.previous_sha,
        branch:             d.branch,
        author:             d.author,
        kind:               d.kind,
        status:             d.status,
        started_at:         d.started_at,
        finished_at:        d.finished_at,
        duration_seconds:   d.duration_seconds,
        commit_count:       d.deploy_commits.count,
        changed_file_count: d.deploy_changed_files.count
      }
    end

    def detail_attrs(d)
      list_attrs(d).merge(
        reverts_deploy_id: d.reverts_deploy_id,
        metadata:          d.metadata,
        commits:           d.deploy_commits.map { |c|
          { sha: c.sha, author: c.author, message: c.message, committed_at: c.committed_at }
        },
        changed_files: d.deploy_changed_files.map { |f|
          { path: f.path, change_type: f.change_type }
        }
      )
    end
  end
end
