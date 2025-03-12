# typed: false
# frozen_string_literal: true

require 'test_helper'

module Wachtwoord
  class TestSecretNameMatcher < Minitest::Test
    def test_that_it_respects_the_allow_list
      instance_without_allow_list = described_class.new
      Wachtwoord.configure do |config|
        config.allowed_secret_names << 'SECRET_AUTH_TOKEN'
      end
      instance_with_allow_list = described_class.new

      test_name = " secret_auth_TOKEN\n"

      assert instance_without_allow_list.secret_name?(test_name)
      refute instance_with_allow_list.secret_name?(test_name)
    end

    def test_that_it_uses_secret_name_patterns
      instance = described_class.new

      assert instance.secret_name?('some_SECRET')
      assert instance.secret_name?('AUTH_thing')
      assert instance.secret_name?('database_connection_pool_url')
      assert instance.secret_name?('a dsn value')
      refute instance.secret_name?('literally anything')
      refute instance.secret_name?(nil)
      refute instance.secret_name?('')

      Wachtwoord.configure do |config|
        config.secret_name_tokens << 'anything'
      end
      instance_with_custom_token = described_class.new

      assert instance_with_custom_token.secret_name?('literally anything')
      refute instance_with_custom_token.secret_name?('literally anythings')
    end

    def test_that_it_ignores_secret_versions
      instance_with_default_prefix = described_class.new
      Wachtwoord.configure do |config|
        config.secret_version_env_name_prefix = 'SOME_PREFIX_'
      end
      instance_without_default_prefix = described_class.new

      refute instance_with_default_prefix.secret_name?('SECRET_VERSION_ENV_BLAH_SECRET')
      refute instance_without_default_prefix.secret_name?('SOME_PREFIX_BLAH_SECRET')
      assert instance_without_default_prefix.secret_name?('SECRET_VERSION_ENV_BLAH_SECRET')
      assert instance_with_default_prefix.secret_name?('SOME_PREFIX_BLAH_SECRET')
    end
  end
end
