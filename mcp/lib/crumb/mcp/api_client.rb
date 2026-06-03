require "faraday"
require "json"
require "shellwords"
require "uri"

module Crumb
  module MCP
    class ApiClient
      class Error < StandardError; end

      def self.for(slug)
        ep    = Registry.endpoint_for(slug)
        token = ENV.fetch(ep[:token_env]) do
          raise Error, "Missing env var #{ep[:token_env]} for endpoint #{slug}"
        end
        new(ep[:base_url], token, ep[:repo_path], slug)
      end

      def initialize(base_url, token, repo_path, slug)
        @base_url  = base_url.chomp("/")
        @token     = token
        @repo_path = repo_path
        @slug      = slug
      end

      def recent(limit: 20)
        data = get("/deploys?limit=#{limit}")
        (data["deploys"] || []).map { |d| d.merge("endpoint" => @slug) }
      end

      def detail(id)
        get("/deploys/#{id}").merge("endpoint" => @slug)
      end

      def touching(path_prefix, limit: 20)
        data = get("/deploys?touching=#{URI.encode_uri_component(path_prefix)}&limit=#{limit}")
        (data["deploys"] || []).map { |d| d.merge("endpoint" => @slug) }
      end

      def diff(sha, repo_path: nil)
        dir = repo_path || @repo_path
        raise Error, "No repo_path configured for endpoint #{@slug}" unless dir
        `git -C #{Shellwords.escape(dir)} show #{Shellwords.escape(sha)} --stat 2>&1`
      end

      private

      def get(path)
        response = Faraday.get("#{@base_url}#{path}", nil,
          "Authorization" => "Bearer #{@token}",
          "Accept"        => "application/json")
        raise Error, "HTTP #{response.status} from #{@slug}" unless response.status == 200
        JSON.parse(response.body)
      end
    end
  end
end
