# typed: true
# frozen_string_literal: true

module Wachtwoord
  class Configuration
    extend T::Sig
    SECRET_NAME_TOKENS = %w[
      APP_ID
      AUTH
      CONNECTION_STRING
      DATABASE_.*URL
      DSN
      HEADERS
      KEY
      PASSWORD
      PASSPHRASE
      POSTGRES_URL
      PROXY_URL
      SECRET
      SLACK_WEBHOOK
      SID
      SIGNATURE
      TOKEN
      REDIS_.*URL
    ].freeze
    DO_NOT_IMPORT_NAMES = %w[
      AWS_SECRET_ACCESS_KEY
      HEROKU_APP_DEFAULT_DOMAIN_NAME
      HEROKU_APP_ID
      HEROKU_APP_NAME
      HEROKU_RELEASE_COMMIT
      HEROKU_RELEASE_CREATED_AT
      HEROKU_RELEASE_DESCRIPTION
      HEROKU_RELEASE_VERSION
      HEROKU_SLUG_COMMIT
      HEROKU_SLUG_DESCRIPTION
    ].freeze
    SECRET_VERSION_ENV_NAME_PREFIX = 'SECRET_VERSION_ENV_'
    VERSION_STAGE_PREFIX = 'CLEO-'

    sig { returns(T::Array[String]) }
    attr_accessor :secret_name_tokens

    sig { returns(T::Array[String]) }
    attr_accessor :do_not_import_names

    sig { returns(T::Array[String]) }
    attr_accessor :allowed_config_names

    sig { returns(String) }
    attr_accessor :secret_version_env_name_prefix

    sig { returns(T.nilable(String)) }
    attr_accessor :secrets_namespace

    sig { returns(String) }
    attr_accessor :version_stage_prefix

    sig { returns(T::Boolean) }
    attr_accessor :enabled

    sig { returns(T.untyped) }
    attr_accessor :logger

    def initialize
      @secret_name_tokens = SECRET_NAME_TOKENS.dup + ENV.fetch('WACHTWOORD_SECRET_NAME_TOKENS', '').split(',')
      @do_not_import_names = DO_NOT_IMPORT_NAMES.dup + ENV.fetch('WACHTWOORD_DO_NOT_IMPORT_NAMES', '').split(',')
      @secret_version_env_name_prefix = SECRET_VERSION_ENV_NAME_PREFIX
      @allowed_config_names = ENV.fetch('WACHTWOORD_ALLOWED_CONFIG_NAMES', '').split(',')
      @version_stage_prefix = VERSION_STAGE_PREFIX
      @logger = Logger.new($stdout, level: T.unsafe(ENV.fetch('LOG_LEVEL', Logger::INFO)))
      @secrets_namespace = ENV.fetch('WACHTWOORD_SECRETS_NAMESPACE', nil)
      @enabled = ENV.fetch('WACHTWOORD_ENABLED', 'true') == 'true'
    end
  end
end
