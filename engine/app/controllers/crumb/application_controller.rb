module Crumb
  class ApplicationController < ActionController::API
    before_action :authenticate!

    private

    def authenticate!
      head :unauthorized unless valid_write_secret? || valid_read_token?
    end

    def require_write_secret!
      head :unauthorized unless valid_write_secret?
    end

    def valid_write_secret?
      expected = Crumb.config.ingest_secret
      return false if expected.blank?
      ActiveSupport::SecurityUtils.secure_compare(bearer_token.to_s, expected)
    end

    def valid_read_token?
      @current_token = Crumb::AccessToken.authenticate(bearer_token.to_s)
      @current_token.present?
    end

    def bearer_token
      request.headers["Authorization"]&.delete_prefix("Bearer ")
    end
  end
end
