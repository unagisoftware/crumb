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

      def inject_kamal_secret
        deploy_files = Dir.glob(File.join(destination_root, "config/deploy*.yml"))

        if deploy_files.empty?
          say_status :skip, "no config/deploy*.yml found — add CRUMB_INGEST_SECRET to env.secret manually", :yellow
          return
        end

        deploy_files.each do |abs_path|
          relative_path = abs_path.delete_prefix(destination_root + "/")
          content = File.read(abs_path)

          next if content.include?("CRUMB_INGEST_SECRET")

          if content.match?(/^env:\n  secret:/)
            inject_into_file relative_path, "    - CRUMB_INGEST_SECRET\n", after: "env:\n  secret:\n"
          else
            say_status :skip, "#{relative_path} — no top-level env.secret block found; add CRUMB_INGEST_SECRET manually", :yellow
          end
        end

        say_status :info, "Remember to add CRUMB_INGEST_SECRET to your Kamal secrets file and secret manager", :blue
      end
    end
  end
end
