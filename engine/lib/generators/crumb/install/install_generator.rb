require "rails/generators"

module Crumb
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a Crumb initializer and copies Kamal hook templates."

      def create_initializer
        template "initializer.rb", "config/initializers/crumb.rb"
      end

      def copy_hooks
        empty_directory ".kamal/hooks"
        template "pre-deploy",  ".kamal/hooks/pre-deploy"
        template "post-deploy", ".kamal/hooks/post-deploy"
        chmod ".kamal/hooks/pre-deploy",  0o755
        chmod ".kamal/hooks/post-deploy", 0o755
      end
    end
  end
end
