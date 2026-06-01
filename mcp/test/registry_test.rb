require "test_helper"
require "tmpdir"

class RegistryTest < Minitest::Test
  def setup
    Crumb::MCP::Registry.instance_variable_set(:@config, nil)
  end

  def with_config(yaml)
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      File.write(config_path, yaml)
      stub_const(Crumb::MCP::Registry, :CONFIG_PATH, config_path) do
        yield
      end
    end
  end

  def stub_const(mod, const, value)
    old = mod.const_get(const)
    mod.send(:remove_const, const)
    mod.const_set(const, value)
    yield
  ensure
    mod.send(:remove_const, const)
    mod.const_set(const, old)
    Crumb::MCP::Registry.instance_variable_set(:@config, nil)
  end

  def test_all_slugs
    yaml = <<~YAML
      endpoints:
        my-app:
          base_url: https://app.example/crumb
          token_env: MY_APP_TOKEN
        my-app-staging:
          base_url: https://staging.example/crumb
          token_env: MY_APP_STAGING_TOKEN
    YAML
    with_config(yaml) do
      assert_equal %w[my-app my-app-staging], Crumb::MCP::Registry.all_slugs
    end
  end

  def test_endpoint_for_returns_parsed_attrs
    yaml = <<~YAML
      endpoints:
        my-app:
          base_url: https://app.example/crumb
          token_env: MY_APP_TOKEN
          repo_path: ~/code/my-app
    YAML
    with_config(yaml) do
      ep = Crumb::MCP::Registry.endpoint_for("my-app")
      assert_equal "https://app.example/crumb", ep[:base_url]
      assert_equal "MY_APP_TOKEN",              ep[:token_env]
      assert ep[:repo_path].start_with?("/")
    end
  end

  def test_endpoint_for_raises_on_unknown_slug
    yaml = "endpoints:\n  my-app:\n    base_url: https://x\n    token_env: T\n"
    with_config(yaml) do
      assert_raises(ArgumentError) { Crumb::MCP::Registry.endpoint_for("unknown") }
    end
  end
end
