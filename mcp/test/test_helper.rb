require "minitest/autorun"
require "webmock/minitest"
require "crumb/mcp"

module StubHelper
  def stub_method(obj, method_name, value, &block)
    original = obj.method(method_name)
    singleton = obj.singleton_class
    singleton.send(:remove_method, method_name) if singleton.method_defined?(method_name, false)
    obj.define_singleton_method(method_name) do |*args, **kwargs|
      value.respond_to?(:call) ? value.call(*args, **kwargs) : value
    end
    block.call
  ensure
    singleton.send(:remove_method, method_name) if singleton.method_defined?(method_name, false)
    obj.define_singleton_method(method_name, &original)
  end
end

class Minitest::Test
  include StubHelper
end
