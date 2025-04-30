# typed: false
# frozen_string_literal: true

require 'test_helper'

module Wachtwoord
  class TestFetch < Minitest::Test
    def setup
      Wachtwoord.configure do |config|
        config.secrets_namespace = 'meetcleo_production'
      end
      @client = mock(:client)
      @secret = Secret.new(name: 'something')
      @version_stage = VersionStage.new(version_number: 1)
    end

    def test_secret_values_by_env_name_with_latest_version
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:))

      result = instance(desired_version_stages_by_secret: { secret => version_stage }).secret_values_by_env_name

      assert_equal({ 'SOMETHING' => 'blah' }, result)
    end

    def test_secret_values_by_env_name_with_additional_response
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:, next_token: 'not expected'))

      assert_raises(Fetch::AdditionalSecretsError) do
        instance(desired_version_stages_by_secret: { secret => version_stage }).secret_values_by_env_name
      end
    end

    def test_secret_values_by_env_name_with_response_error
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:, errors: [{ error_code: 'blah' }]))

      assert_raises(Fetch::FetchingSecretsError) do
        instance(desired_version_stages_by_secret: { secret => version_stage }).secret_values_by_env_name
      end
    end

    def test_secret_values_by_env_name_with_missing_secret
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:, errors: [{ error_code: 'ResourceNotFoundException' }]))

      assert_raises(Fetch::MissingSecretsError) do
        instance(desired_version_stages_by_secret: { secret => version_stage }).secret_values_by_env_name
      end

      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:, errors: [{ error_code: 'ResourceNotFoundException' }]))
      result = instance(desired_version_stages_by_secret: { secret => version_stage }, raise_if_not_found: false).secret_values_by_env_name

      assert_equal({ 'SOMETHING' => 'blah' }, result)
    end

    def test_secret_values_by_env_name_with_newest_version
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:))
      client.expects(:get_secret_value).never

      result = instance(desired_version_stages_by_secret: { secret => VersionStage.newest_version_stage }).secret_values_by_env_name

      assert_equal({ 'SOMETHING' => 'blah' }, result)
    end

    def test_secret_values_by_env_name_with_older_version
      other_version_stage = VersionStage.new(version_number: version_stage.version_number + 1)
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:))
      client.expects(:get_secret_value).with({ secret_id: secret.namespaced_name, version_stage: other_version_stage.serialized_version_stage }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          created_date: Time.parse('2024-11-15T00:05:07Z'),
          name: secret.namespaced_name,
          secret_string: '{"value":"blah-2"}',
          version_id: 'EXAMPLE1-90ab-cdef-fedc-ba987SECRET1',
          version_stages: [
            'AWSPREVIOUS',
            other_version_stage.serialized_version_stage
          ]
        }
      )

      result = instance(desired_version_stages_by_secret: { secret => other_version_stage }).secret_values_by_env_name

      assert_equal({ 'SOMETHING' => 'blah-2' }, result)
    end

    def test_secret_values_by_env_name_with_older_version_missing_secret
      other_version_stage = VersionStage.new(version_number: version_stage.version_number + 1)
      client.expects(:batch_get_secret_value).with({ secret_id_list: [secret.namespaced_name] }).returns(response(secret:, version_stage:))
      client.expects(:get_secret_value).with({ secret_id: secret.namespaced_name, version_stage: other_version_stage.serialized_version_stage }).raises(::Aws::SecretsManager::Errors::ResourceNotFoundException.new(nil, nil))

      assert_raises(Fetch::MissingSecretsError) do
        instance(desired_version_stages_by_secret: { secret => other_version_stage }).secret_values_by_env_name
      end
    end

    private

    def instance(desired_version_stages_by_secret:, raise_if_not_found: true)
      described_class.new(desired_version_stages_by_secret:, client:, raise_if_not_found:)
    end

    def response(secret:, version_stage:, errors: [], next_token: nil)
      {
        errors:,
        next_token:,
        secret_values: [
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
      }
    end

    attr_reader :client, :secret, :version_stage
  end
end
