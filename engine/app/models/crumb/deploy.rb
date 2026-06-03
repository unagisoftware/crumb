module Crumb
  class Deploy < ApplicationRecord
    has_many :deploy_commits,       dependent: :destroy, foreign_key: :crumb_deploy_id
    has_many :deploy_changed_files, dependent: :destroy, foreign_key: :crumb_deploy_id
    belongs_to :reverts_deploy, class_name: "Crumb::Deploy", optional: true

    VALID_KINDS    = %w[deploy rollback].freeze
    VALID_STATUSES = %w[running success failed].freeze

    validates :sha,    presence: true
    validates :kind,   inclusion: { in: VALID_KINDS }
    validates :status, inclusion: { in: VALID_STATUSES }

    # finished_at DESC puts in-progress (running, null finished_at) deploys first in
    # Postgres (NULLS FIRST), with id as a stable tiebreaker.
    scope :recent, -> { order(finished_at: :desc, id: :desc) }
  end
end
