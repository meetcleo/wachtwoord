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
require_relative 'wachtwoord/import'
require_relative 'wachtwoord/railtie' if defined? Rails

module Wachtwoord
  extend T::Sig
  class ChangingExistingEnvError < StandardError; end
  class UknownClashBehaviourError < StandardError; end

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

    sig { params(clash_behaviour: T.nilable(Symbol)).void }
    def load_secrets_into_env(clash_behaviour: :raise)
      clash_behaviour = T.must(clash_behaviour)
      secret_values_by_env_name = Fetch.new(desired_version_stages_by_secret:, client:).secret_values_by_env_name
      secret_values_by_env_name.each do |env_name, secret_value|
        new_secret_value = new_value_for_env(env_name:, secret_value:, clash_behaviour:)
        configuration.logger.debug { "[Wachtwoord] setting ENV: #{env_name}" }
        ENV[env_name] = new_secret_value
      end
    end

    sig { returns(T.untyped) }
    def client
      T.let(::Aws::SecretsManager::Client, T.untyped).new(region:)
    end

    private

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

    sig { params(env_name: String, secret_value: String, clash_behaviour: Symbol).returns(String) }
    def new_value_for_env(env_name:, secret_value:, clash_behaviour:)
      existing_secret_value = ENV.fetch(env_name, nil)
      return secret_value unless existing_secret_value && existing_secret_value != secret_value

      case clash_behaviour
      when :raise
        raise ChangingExistingEnvError, "Unexpected change to ENV: #{env_name}"
      when :preserve_env
        configuration.logger.warn { "[Wachtwoord] not overwriting existing ENV: #{env_name}" }
        existing_secret_value
      when :overwrite_env
        configuration.logger.warn { "[Wachtwoord] overwriting existing ENV: #{env_name}" }
        secret_value
      else
        raise UknownClashBehaviourError, "Unknown clash behaviour: #{clash_behaviour}"
      end
    end
  end
end
