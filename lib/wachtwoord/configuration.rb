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
    SECRET_VERSION_ENV_NAME_PREFIX = 'SECRET_VERSION_ENV_'
    VERSION_STAGE_PREFIX = 'CLEO-'

    sig { returns(T::Array[String]) }
    attr_accessor :secret_name_tokens

    sig { returns(T::Array[String]) }
    attr_accessor :allowed_secret_names

    sig { returns(String) }
    attr_accessor :secret_version_env_name_prefix

    sig { returns(T.nilable(String)) }
    attr_accessor :secrets_namespace

    sig { returns(String) }
    attr_accessor :version_stage_prefix

    def initialize
      @secret_name_tokens = SECRET_NAME_TOKENS.dup
      @secret_version_env_name_prefix = SECRET_VERSION_ENV_NAME_PREFIX
      @allowed_secret_names = []
      @version_stage_prefix = VERSION_STAGE_PREFIX
    end
  end
end
