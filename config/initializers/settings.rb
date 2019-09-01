module Deepworld
  class Configuration
    
    private

    def self.configure_fog
      redefine_const 'S3', Fog::Storage.new({
        provider: Settings.fog.provider,
        aws_access_key_id: Settings.fog.access_key_id,
        aws_secret_access_key: Settings.fog.secret, 
        scheme: 'http'})
    end
  end
end

Deepworld::Configuration.configure! Deepworld::Env.environment