# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_01_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "crumb_access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "owner", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_crumb_access_tokens_on_token_digest", unique: true
  end

  create_table "crumb_deploy_changed_files", force: :cascade do |t|
    t.string "change_type"
    t.bigint "crumb_deploy_id", null: false
    t.string "path", null: false
    t.index ["crumb_deploy_id", "path"], name: "index_crumb_deploy_changed_files_on_crumb_deploy_id_and_path"
    t.index ["crumb_deploy_id"], name: "index_crumb_deploy_changed_files_on_crumb_deploy_id"
    t.index ["path"], name: "index_crumb_deploy_changed_files_on_path", opclass: :text_pattern_ops
  end

  create_table "crumb_deploy_commits", force: :cascade do |t|
    t.string "author"
    t.datetime "committed_at"
    t.bigint "crumb_deploy_id", null: false
    t.text "message"
    t.string "sha", null: false
    t.index ["crumb_deploy_id", "sha"], name: "index_crumb_deploy_commits_on_crumb_deploy_id_and_sha", unique: true
    t.index ["crumb_deploy_id"], name: "index_crumb_deploy_commits_on_crumb_deploy_id"
  end

  create_table "crumb_deploys", force: :cascade do |t|
    t.string "author"
    t.string "branch"
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "finished_at"
    t.string "kind", default: "deploy", null: false
    t.jsonb "metadata", default: {}
    t.string "previous_sha"
    t.bigint "reverts_deploy_id"
    t.string "sha", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["sha"], name: "index_crumb_deploys_on_sha"
    t.index ["status", "finished_at"], name: "index_crumb_deploys_on_status_and_finished_at"
  end

  add_foreign_key "crumb_deploy_changed_files", "crumb_deploys"
  add_foreign_key "crumb_deploy_commits", "crumb_deploys"
end
