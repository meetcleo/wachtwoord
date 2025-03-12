# typed: false
# frozen_string_literal: true

module Wachtwoord
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'wachtwoord/secret.rake'
    end
  end
end
