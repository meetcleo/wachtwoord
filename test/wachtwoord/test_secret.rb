# typed: false
# frozen_string_literal: true

require 'test_helper'

module Wachtwoord
  class TestSecret < Minitest::Test
    def test_namespace
      assert_nil described_class.namespace

      Wachtwoord.configure do |config|
        config.secrets_namespace = 'meetcleo_production'
      end

      assert_equal 'meetcleo_production', described_class.namespace
    end

    def test_version_env_name_prefix
      assert_equal 'SECRET_VERSION_ENV_', described_class.version_env_name_prefix

      Wachtwoord.configure do |config|
        config.secret_version_env_name_prefix = 'SOME_PREFIX_'
      end

      assert_equal 'SOME_PREFIX_', described_class.version_env_name_prefix
    end

    def test_namespaced_name
      assert_equal '/blah', described_class.namespaced_name(name: 'blah', override_namespace: nil)
      assert_equal 'namespace/blah', described_class.namespaced_name(name: 'blah', override_namespace: 'namespace')

      Wachtwoord.configure do |config|
        config.secrets_namespace = 'meetcleo_production'
      end

      assert_equal 'meetcleo_production/blah', described_class.namespaced_name(name: 'blah', override_namespace: nil)
      assert_equal 'namespace/blah', described_class.namespaced_name(name: 'blah', override_namespace: 'namespace')
    end

    def test_prefixed_name
      assert_equal 'SECRET_VERSION_ENV_BLAH', described_class.prefixed_name(name: 'blah')
    end

    def test_name_without_prefix
      assert_equal 'blah', described_class.name_without_prefix(prefixed_name: 'SECRET_VERSION_ENV_BLAH')
      assert_nil described_class.name_without_prefix(prefixed_name: nil)
    end

    def test_name_without_namespace
      assert_nil described_class.name_without_namespace(namespaced_name: nil)
      assert_equal 'blah', described_class.name_without_namespace(namespaced_name: 'namespace/blah')
    end

    def test_try_parse
      assert_nil described_class.try_parse(prefixed_name: 'anything')
      assert_equal described_class.new(name: 'blah'), described_class.try_parse(prefixed_name: 'SECRET_VERSION_ENV_BLAH')
    end

    def test_new
      assert_equal described_class.new(name: 'blah'), described_class.new(prefixed_name: 'SECRET_VERSION_ENV_BLAH')
      assert_equal described_class.new(name: 'blah'), described_class.new(namespaced_name: 'namespace/blah')
      assert_equal described_class.new(name: 'blah'), described_class.new(name: 'blah')
      assert_raises(Secret::NilSecretName) do
        described_class.new(name: nil)
      end

      assert_equal 'override/blah', described_class.new(name: 'blah', override_namespace: 'override').namespaced_name
      assert_equal 'SECRET_VERSION_ENV_BLAH', described_class.new(name: 'blah').prefixed_name
      assert_equal 'blah', described_class.new(name: 'blah').name
    end

    def test_env_name
      assert_equal 'BLAH', described_class.new(name: 'blah').env_name
    end
  end
end
