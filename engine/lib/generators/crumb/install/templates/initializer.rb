Crumb.configure do |c|
  c.ingest_secret = ENV.fetch("CRUMB_INGEST_SECRET", nil)
end
