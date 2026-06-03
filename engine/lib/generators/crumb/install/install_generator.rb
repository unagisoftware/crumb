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

        # Crumb owns the sub-hook logic — always (over)write so updates land on re-run.
        template "crumb-pre-deploy",  ".kamal/hooks/crumb-pre-deploy",  force: true
        template "crumb-post-deploy", ".kamal/hooks/crumb-post-deploy", force: true
        chmod ".kamal/hooks/crumb-pre-deploy",  0o755
        chmod ".kamal/hooks/crumb-post-deploy", 0o755

        # The operator owns crumb-env (their API URLs) — create once, never clobber.
        if File.exist?(File.join(destination_root, ".kamal/hooks/crumb-env"))
          say_status :skip, ".kamal/hooks/crumb-env already exists — not overwriting", :yellow
        else
          template "crumb-env", ".kamal/hooks/crumb-env"
        end

        # The host owns these — create a thin wrapper if missing, otherwise
        # append a call to the Crumb sub-hook (idempotent via marker check).
        ensure_hook_calls_crumb "pre-deploy",  "crumb-pre-deploy"
        ensure_hook_calls_crumb "post-deploy", "crumb-post-deploy"
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

      def show_post_install
        say_status :crumb, "installed — next steps:", :green
        say <<~MSG

          1. Edit .kamal/hooks/crumb-env and set the Crumb API URL for each deploy destination.
          2. Add CRUMB_INGEST_SECRET to your secret manager and Kamal secrets file.
          3. Make sure CRUMB_INGEST_SECRET reaches the deploy hooks locally — export it,
             or fetch it from your secret manager inside crumb-env (see the example there).
        MSG
      end

      private

      def ensure_hook_calls_crumb(hook, crumb_hook)
        dest      = ".kamal/hooks/#{hook}"
        abs_path  = File.join(destination_root, dest)
        call_line = %(bash "$(dirname "$0")/#{crumb_hook}" "$@")

        unless File.exist?(abs_path)
          create_file dest, <<~BASH
            #!/usr/bin/env bash
            set -euo pipefail

            # Crumb deployment tracking
            #{call_line}
          BASH
          chmod dest, 0o755
          return
        end

        if File.read(abs_path).include?(crumb_hook)
          say_status :skip, "#{dest} already calls #{crumb_hook}", :yellow
        else
          append_to_file dest, "\n# Crumb deployment tracking\n#{call_line}\n"
        end
      end
    end
  end
end
