module Crumb
  class AccessToken < ApplicationRecord
    validates :owner, :token_digest, presence: true
    validates :token_digest, uniqueness: true

    def active?
      revoked_at.nil?
    end

    def self.authenticate(raw_token)
      return nil if raw_token.blank?
      digest = Digest::SHA256.hexdigest(raw_token)
      token  = find_by(token_digest: digest)
      return nil unless token&.active?
      token.touch(:last_used_at)
      token
    end
  end
end
