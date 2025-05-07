# typed: false
# frozen_string_literal: true

module Wachtwoord
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'wachtwoord/secret.rake'
    end

    initializer 'wachtwoord', after: 'dotenv' do |_app|
      Wachtwoord.configure do |config|
        config.logger = Rails.logger
      end
    end

    config.before_configuration do
      next unless Wachtwoord.configuration.enabled

      start_at = Time.now
      Wachtwoord.load_secrets_into_env(clash_behaviour: :preserve_env)
      end_at = Time.now
      Wachtwoord.configuration.logger.info("[Wachtwoord] loaded secrets in #{end_at - start_at}s")
    end
  end
end
