require "test_helper"
require "rails/generators/test_case"
require "generators/crumb/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Crumb::Generators::InstallGenerator
  destination File.expand_path("../../../tmp/generator_test", __dir__)

  setup do
    prepare_destination
  end

  test "creates the initializer" do
    run_generator
    assert_file "config/initializers/crumb.rb" do |content|
      assert_match "Crumb.configure", content
      assert_match "CRUMB_INGEST_SECRET", content
    end
  end

  test "writes crumb-env with per-destination API URLs and a single secret var" do
    run_generator
    assert_file ".kamal/hooks/crumb-env" do |content|
      assert_match "CRUMB_API_URL", content
      assert_match "CRUMB_INGEST_SECRET", content
      assert_match(/case .*DEST/, content)
    end
  end

  test "writes the crumb-pre-deploy sub-hook that sources crumb-env and posts a deploy" do
    run_generator
    assert_file ".kamal/hooks/crumb-pre-deploy" do |content|
      assert_match "crumb-env", content
      assert_match "/deploys", content
    end
  end

  test "writes the crumb-post-deploy sub-hook that sources crumb-env and patches the deploy" do
    run_generator
    assert_file ".kamal/hooks/crumb-post-deploy" do |content|
      assert_match "crumb-env", content
      assert_match "rollback", content
      assert_match "PATCH", content
    end
  end

  test "does not overwrite an existing crumb-env" do
    FileUtils.mkdir_p File.join(destination_root, ".kamal/hooks")
    File.write File.join(destination_root, ".kamal/hooks/crumb-env"), "# my custom urls\n"

    run_generator

    assert_file ".kamal/hooks/crumb-env" do |content|
      assert_match "my custom urls", content
    end
  end

  test "creates thin wrapper hooks that call the crumb sub-hooks when none exist" do
    run_generator
    assert_file ".kamal/hooks/pre-deploy" do |content|
      assert_match "crumb-pre-deploy", content
    end
    assert_file ".kamal/hooks/post-deploy" do |content|
      assert_match "crumb-post-deploy", content
    end
  end

  test "appends the crumb call to an existing host hook" do
    FileUtils.mkdir_p File.join(destination_root, ".kamal/hooks")
    File.write File.join(destination_root, ".kamal/hooks/pre-deploy"), <<~BASH
      #!/usr/bin/env bash
      set -euo pipefail

      echo "host's own pre-deploy logic"
    BASH

    run_generator

    assert_file ".kamal/hooks/pre-deploy" do |content|
      assert_match "host's own pre-deploy logic", content
      assert_match "crumb-pre-deploy", content
    end
  end

  test "does not append the crumb call twice when re-run" do
    run_generator
    run_generator

    assert_file ".kamal/hooks/pre-deploy" do |content|
      assert_equal 1, content.scan("crumb-pre-deploy").length
    end
  end

  test "injects CRUMB_INGEST_SECRET into deploy ymls with top-level env.secret" do
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/deploy.production.yml"), <<~YAML
      env:
        secret:
          - RAILS_MASTER_KEY
    YAML

    run_generator

    assert_file "config/deploy.production.yml" do |content|
      assert_match "CRUMB_INGEST_SECRET", content
    end
  end

  test "skips deploy ymls that already have CRUMB_INGEST_SECRET" do
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/deploy.production.yml"), <<~YAML
      env:
        secret:
          - CRUMB_INGEST_SECRET
          - RAILS_MASTER_KEY
    YAML

    run_generator

    assert_file "config/deploy.production.yml" do |content|
      assert_equal 1, content.scan("CRUMB_INGEST_SECRET").length
    end
  end
end
