namespace :crumb do
  namespace :tokens do
    desc "Mint a read token. Usage: rails crumb:tokens:mint OWNER=email@example.com"
    task mint: :environment do
      owner = ENV.fetch("OWNER") { abort "Usage: rails crumb:tokens:mint OWNER=email@example.com" }
      raw   = SecureRandom.hex(32)
      Crumb::AccessToken.create!(owner: owner, token_digest: Digest::SHA256.hexdigest(raw))
      puts "Token for #{owner} (shown once):"
      puts raw
    end
  end
end
