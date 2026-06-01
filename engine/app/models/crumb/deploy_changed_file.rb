module Crumb
  class DeployChangedFile < ApplicationRecord
    belongs_to :deploy, foreign_key: :crumb_deploy_id
  end
end
