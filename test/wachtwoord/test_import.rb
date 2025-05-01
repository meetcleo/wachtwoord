# typed: false
# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

module Wachtwoord
  class TestImport < Minitest::Test
    def setup
      @namespace = 'meetcleo_production'
      Wachtwoord.configure do |config|
        config.secrets_namespace = namespace
      end
      @client = mock(:client)
      @secret = Secret.new(name: 'secret_key_1')
      @version_stage = VersionStage.new(version_number: 1)
      Wachtwoord.stubs(:client).returns(client)
    end

    def test_start
      expect_fetch_secret
      expect_create_secret

      Tempfile.open('foo') do |dotenv_file|
        described_class.new(envs_from_source: { 'config_1' => 'blah1', 'secret_key_1' => 'blah2', 'CONFIG_2' => "a\nb\nc" }, dotenv_file_path: dotenv_file.path, overwrite: false, override_namespace: namespace).start

        assert_equal("CONFIG_1=blah1\nCONFIG_2=\"a\nb\nc\"\nSECRET_VERSION_ENV_SECRET_KEY_1=1", dotenv_file.read)
      end
    end

    def test_start_duplicate_secret_override
      expect_fetch_secret(already_exists: true)
      expect_create_secret

      Tempfile.open('foo') do |dotenv_file|
        described_class.new(envs_from_source: { 'config_1' => 'blah1', 'secret_key_1' => 'blah2' }, dotenv_file_path: dotenv_file.path, overwrite: true, override_namespace: namespace).start

        assert_equal("CONFIG_1=blah1\nSECRET_VERSION_ENV_SECRET_KEY_1=1", dotenv_file.read)
      end
    end

    def test_start_duplicate_secret_no_override
      expect_fetch_secret(already_exists: true)

      Tempfile.open('foo') do |dotenv_file|
        assert_raises(Import::ExistingSecretError) do
          described_class.new(envs_from_source: { 'config_1' => 'blah1', 'secret_key_1' => 'blah2' }, dotenv_file_path: dotenv_file.path, overwrite: false, override_namespace: namespace).start
        end
      end
    end

    def test_start_duplicate_config_override
      Tempfile.open('foo') do |dotenv_file|
        dotenv_file.write('config_1=blah')
        dotenv_file.rewind
        described_class.new(envs_from_source: { 'config_1' => 'blah1' }, dotenv_file_path: dotenv_file.path, overwrite: true, override_namespace: namespace).start

        assert_equal('CONFIG_1=blah1', dotenv_file.read)
      end
    end

    def test_start_duplicate_config_no_override
      Tempfile.open('foo') do |dotenv_file|
        dotenv_file.write('config_1=blah')
        dotenv_file.rewind
        assert_raises(Import::ExistingConfigError) do
          described_class.new(envs_from_source: { 'config_1' => 'blah1' }, dotenv_file_path: dotenv_file.path, overwrite: false, override_namespace: namespace).start
        end
      end
    end

    private

    def expect_fetch_secret(already_exists: false)
      errors = already_exists ? [] : [error_code: 'ResourceNotFoundException']
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret: already_exists ? secret : nil, version_stage:, errors:))
    end

    def expect_create_secret
      client.expects(:list_secret_version_ids).with({ secret_id: secret.namespaced_name }).raises(::Aws::SecretsManager::Errors::ResourceNotFoundException.new(nil, nil))
      client.expects(:create_secret).with({ name: secret.namespaced_name, secret_string: '{"value":"blah2"}', description: 'imported from heroku' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: secret.namespaced_name,
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE'
        }
      )

      client.expects(:update_secret_version_stage).with({ move_to_version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE', secret_id: secret.namespaced_name, version_stage: 'CLEO-001' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: secret.namespaced_name,
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE',
          version_stages: [
            'AWSCURRENT'
          ]
        }
      )
    end

    def response(secret:, version_stage:, errors: [], next_token: nil)
      {
        errors:,
        next_token:,
        secret_values: if secret
                         [
                           {
                             arn: '&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret1-a1b2c3',
                             created_date: Time.parse('2024-11-15T00:05:07Z'),
                             name: secret.namespaced_name,
                             secret_string: '{"value":"blah"}',
                             version_id: 'a1b2c3d4-5678-90ab-cdef-EXAMPLEaaaaa',
                             version_stages: [
                               'AWSCURRENT',
                               version_stage.serialized_version_stage
                             ]
                           }
                         ]
                       else
                         []
                       end
      }
    end

    attr_reader :client, :secret, :version_stage, :namespace
  end
end
