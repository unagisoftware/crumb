class CreateCrumbTables < ActiveRecord::Migration[7.0]
  def change
    create_table :crumb_deploys do |t|
      t.string   :sha,               null: false
      t.string   :previous_sha
      t.string   :branch
      t.string   :author
      t.string   :kind,              null: false, default: "deploy"
      t.bigint   :reverts_deploy_id
      t.string   :status,            null: false, default: "running"
      t.datetime :started_at
      t.datetime :finished_at
      t.integer  :duration_seconds
      t.jsonb    :metadata,          default: {}
      t.timestamps
    end
    add_index :crumb_deploys, :sha
    add_index :crumb_deploys, [ :status, :finished_at ]

    create_table :crumb_deploy_commits do |t|
      t.references :crumb_deploy, null: false, foreign_key: true
      t.string   :sha,          null: false
      t.string   :author
      t.text     :message
      t.datetime :committed_at
    end
    add_index :crumb_deploy_commits, [ :crumb_deploy_id, :sha ], unique: true

    create_table :crumb_deploy_changed_files do |t|
      t.references :crumb_deploy, null: false, foreign_key: true
      t.string :path,        null: false
      t.string :change_type
    end
    add_index :crumb_deploy_changed_files, [ :crumb_deploy_id, :path ]
    add_index :crumb_deploy_changed_files, :path, opclass: :text_pattern_ops

    create_table :crumb_access_tokens do |t|
      t.string   :owner,        null: false
      t.string   :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :crumb_access_tokens, :token_digest, unique: true
  end
end
