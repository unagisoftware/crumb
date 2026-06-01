module Crumb
  class Config
    attr_accessor :ingest_secret
  end

  def self.configure
    yield config
  end

  def self.config
    @config ||= Config.new
  end
end
