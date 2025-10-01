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
  end
end
