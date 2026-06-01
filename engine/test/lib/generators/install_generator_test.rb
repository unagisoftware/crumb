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

  test "copies pre-deploy hook" do
    run_generator
    assert_file ".kamal/hooks/pre-deploy" do |content|
      assert_match "CRUMB_API_URL", content
      assert_match "CRUMB_INGEST_SECRET", content
      assert_match "/deploys", content
    end
  end

  test "copies post-deploy hook" do
    run_generator
    assert_file ".kamal/hooks/post-deploy" do |content|
      assert_match "KAMAL_COMMAND", content
      assert_match "rollback", content
      assert_match "PATCH", content
    end
  end
end
