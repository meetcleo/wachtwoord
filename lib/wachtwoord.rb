# typed: true
# frozen_string_literal: true

require 'aws-sdk-secretsmanager'
require_relative 'wachtwoord/version'
require_relative 'wachtwoord/configuration'
require_relative 'wachtwoord/secret_name_matcher'
require_relative 'wachtwoord/version_stage'
require_relative 'wachtwoord/secret'
require_relative 'wachtwoord/manager'
require_relative 'wachtwoord/railtie' if defined? Rails

module Wachtwoord
  extend T::Sig
  class Error < StandardError; end

  class << self
    extend T::Sig
    attr_writer :configuration

    sig { returns(Configuration) }
    def configuration
      @configuration ||= Configuration.new
    end

    sig { returns(Configuration) }
    def reset
      @configuration = Configuration.new
    end

    sig { returns(Configuration) }
    def configure
      yield(configuration)
      configuration
    end

    sig { params(name: String, override_namespace: T.nilable(String), blk: T.proc.params(arg0: Manager).returns(Manager)).returns([String, Integer]) }
    def add_or_update(name:, override_namespace: nil, &blk)
      secret = Secret.new(name:, override_namespace:)
      version_number = Manager.new(secret:, client:, &blk).add_version

      [secret.prefixed_name, version_number]
    end

    private

    sig { returns(T.untyped) }
    def client
      T.let(::Aws::SecretsManager::Client, T.untyped).new(region:)
    end

    sig { returns(String) }
    def region
      ENV.fetch('AWS_REGION')
    end
  end
end
