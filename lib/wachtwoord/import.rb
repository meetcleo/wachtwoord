# typed: true
# frozen_string_literal: true

module Wachtwoord
  class Import
    extend T::Sig
    class ExistingSecretError < StandardError; end
    class ExistingConfigError < StandardError; end

    sig { params(application_name: String).returns(T::Hash[String, String]) }
    def self.envs_from_heroku(application_name:)
      Dotenv::Parser.new(`heroku config -s -a #{application_name} |grep -v '^HEROKU_'`).call
    end

    sig { params(application_name: String, dotenv_file_path: String, overwrite: T::Boolean).void }
    def self.from_heroku(application_name:, dotenv_file_path:, overwrite: false)
      new(envs_from_source: envs_from_heroku(application_name:), dotenv_file_path:, overwrite:, override_namespace: application_name).start
    end

    sig { params(envs_from_source: T::Hash[String, String], dotenv_file_path: String, overwrite: T::Boolean, override_namespace: String).void }
    def initialize(envs_from_source:, dotenv_file_path:, overwrite:, override_namespace:)
      @envs_from_source = envs_from_source
      @dotenv_file_path = dotenv_file_path
      @overwrite = overwrite
      @override_namespace = override_namespace
      @secret_name_matcher = SecretNameMatcher.new
    end

    sig { void }
    def start
      new_configs = configs_from_source.merge(secret_version_stages)
      # Grab anything already in the .env file, but bail if we already have the key, but with a different value
      new_configs.merge!(configs_from_dotenv) do |key, new_config_value, dotenv_value|
        if new_config_value != dotenv_value
          raise ExistingConfigError, "value for #{key} differs from existing #{dotenv_file_path} file, new value: #{new_config_value}, .env value: #{dotenv_value}" unless overwrite

          Wachtwoord.configuration.logger.warn("[Wachtwoord] value for #{key} differs from existing #{dotenv_file_path} file, new value: #{new_config_value}, .env value: #{dotenv_value}. Overwriting with new value.")
        end

        new_config_value
      end

      # TODO: do we need to do any quoting of strings with special chars?
      dotenv_content = new_configs.sort.map { |pair| pair.join('=') }.join("\n")
      File.write(dotenv_file_path, dotenv_content)
    end

    private

    sig { returns(T::Hash[String, String]) }
    def secrets_from_source
      return @secrets_from_source if defined?(@secrets_from_source)

      secrets_keys = envs_from_source.keys.select { |key| secret_name_matcher.secret_name?(key) }
      @secrets_from_source = envs_from_source.slice(*T.unsafe(secrets_keys))
    end

    sig { returns(T::Hash[String, String]) }
    def configs_from_source
      return @configs_from_source if defined?(@configs_from_source)

      configs_keys = envs_from_source.keys.reject { |key| secret_name_matcher.secret_name?(key) }
      @configs_from_source = envs_from_source.slice(*T.unsafe(configs_keys)).transform_keys(&:upcase)
    end

    sig { returns(T::Hash[String, String]) }
    def secret_values_by_env_name
      return @secret_values_by_env_name if defined?(@secret_values_by_env_name)

      # Fetch any existing secrets from SM so we can see if we might change them, which would indicate someone's changed something and we would bail
      desired_version_stages_by_secret = secrets_from_source.to_h do |name, _|
        [Secret.new(name: name.downcase, override_namespace:), VersionStage.newest_version_stage]
      end
      @secret_values_by_env_name = Fetch.new(desired_version_stages_by_secret:, raise_if_not_found: false, client: Wachtwoord.client).secret_values_by_env_name
    end

    sig { returns(T::Hash[String, String]) }
    def secret_version_stages
      return @secret_version_stages if defined?(@secret_version_stages)

      # Chuck the secrets into SM
      @secret_version_stages = secrets_from_source.to_h do |name, value|
        env_name = Secret.new(name: name.downcase, override_namespace:).env_name
        if secret_values_by_env_name[env_name] && secret_values_by_env_name[env_name] != value
          raise ExistingSecretError, "Secret named: #{name} already exists with a different value" unless overwrite

          Wachtwoord.configuration.logger.warn("[Wachtwoord] Secret named: #{name} already exists with a different value. Overwriting with new value.")
        end

        Wachtwoord.configuration.logger.info("[Wachtwoord] Creating secret named: #{name}")
        secret_env, version_number = Wachtwoord.add_or_update(name:, override_namespace:) do |manager|
          manager.value = value
          manager.description = 'imported from heroku'
          manager
        end
        [secret_env, version_number.to_s]
      end
    end

    sig { returns(T::Hash[String, String]) }
    def configs_from_dotenv
      @configs_from_dotenv ||= (File.exist?(dotenv_file_path) ? Dotenv::Parser.new(File.read(dotenv_file_path)).call : {}).transform_keys(&:upcase)
    end

    sig { returns(T::Hash[String, String]) }
    attr_reader :envs_from_source

    sig { returns(String) }
    attr_reader :dotenv_file_path

    sig { returns(T::Boolean) }
    attr_reader :overwrite

    sig { returns(String) }
    attr_reader :override_namespace

    sig { returns(SecretNameMatcher) }
    attr_reader :secret_name_matcher
  end
end
