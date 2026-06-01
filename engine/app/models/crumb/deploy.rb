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

    scope :recent_successes, -> { where(status: "success").order(finished_at: :desc) }
  end
end
