# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'aws-sdk-secretsmanager'
require 'dotenv'
require_relative 'wachtwoord/version'
require_relative 'wachtwoord/configuration'
require_relative 'wachtwoord/secret_name_matcher'
require_relative 'wachtwoord/version_stage'
require_relative 'wachtwoord/secret'
require_relative 'wachtwoord/fetch'
require_relative 'wachtwoord/manager'
require_relative 'wachtwoord/railtie' if defined? Rails

module Wachtwoord
  extend T::Sig
  class ChangingExistingEnvError < StandardError; end

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

    sig { void }
    def load_secrets_into_env
      secret_values_by_env_name = Fetch.new(desired_version_stages_by_secret:, client:).secret_values_by_env_name
      secret_values_by_env_name.each do |env_name, secret_value|
        existing_secret_value = ENV.fetch(env_name, nil)
        raise ChangingExistingEnvError, "Unexpected change to ENV: #{env_name}" if existing_secret_value && existing_secret_value != secret_value

        configuration.logger.debug { "[Wachtwoord] setting ENV: #{env_name}" }
        ENV[env_name] = secret_value
      end
    end

    private

    sig { returns(T.untyped) }
    def client
      T.let(::Aws::SecretsManager::Client, T.untyped).new(region:)
    end

    sig { returns(String) }
    def region
      ENV.fetch('AWS_REGION', 'us-east-1')
    end

    sig { returns(T::Hash[Secret, VersionStage]) }
    def desired_version_stages_by_secret
      ENV.filter_map do |prefixed_name, version_number|
        secret = Secret.try_parse(prefixed_name:)
        next unless secret

        [secret, VersionStage.new(version_number: Integer(version_number))]
      end.to_h
    end
  end
end
