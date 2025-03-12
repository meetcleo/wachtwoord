# typed: false
# frozen_string_literal: true

require 'test_helper'

module Wachtwoord
  class TestManager < Minitest::Test
    def setup
      Wachtwoord.configure do |config|
        config.secrets_namespace = 'meetcleo_production'
      end
      @secret = Secret.new(name: 'blah')
      @client = mock(:client)
    end

    def test_value
      assert_equal 'some value', instance.value
    end

    def test_description
      assert_equal 'some description', instance.description
    end

    def test_existing_secret
      client.expects(:list_secret_version_ids).with({ secret_id: 'meetcleo_production/blah' }).raises(::Aws::SecretsManager::Errors::ResourceNotFoundException.new(nil, nil))

      refute_predicate instance, :existing_secret?

      client.expects(:list_secret_version_ids).with({ secret_id: 'meetcleo_production/blah' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          versions: [
            {
              created_date: Time.now,
              version_id: 'EXAMPLE1-90ab-cdef-fedc-ba987EXAMPLE',
              version_stages: %w[
                AWSPREVIOUS
                CLEO-001
              ]
            }
          ]
        }
      )

      assert_predicate instance, :existing_secret?
    end

    def test_add_version_for_existing_secret
      client.expects(:list_secret_version_ids).with({ secret_id: 'meetcleo_production/blah' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          versions: [
            {
              created_date: Time.now,
              version_id: 'EXAMPLE1-90ab-cdef-fedc-ba987EXAMPLE',
              version_stages: %w[
                AWSPREVIOUS
                CLEO-001
              ]
            }
          ]
        }
      )

      client.expects(:put_secret_value).with({ secret_id: 'meetcleo_production/blah', secret_string: '{"value":"some value"}' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE',
          version_stages: [
            'AWSCURRENT'
          ]
        }
      )

      client.expects(:update_secret_version_stage).with({ move_to_version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE', secret_id: 'meetcleo_production/blah', version_stage: 'CLEO-002' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE',
          version_stages: [
            'AWSCURRENT'
          ]
        }
      )

      assert_equal 2, instance.add_version
    end

    def test_add_version_for_new_secret
      client.expects(:list_secret_version_ids).with({ secret_id: 'meetcleo_production/blah' }).raises(::Aws::SecretsManager::Errors::ResourceNotFoundException.new(nil, nil))

      client.expects(:create_secret).with({ name: 'meetcleo_production/blah', secret_string: '{"value":"some value"}', description: 'some description' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE'
        }
      )

      client.expects(:update_secret_version_stage).with({ move_to_version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE', secret_id: 'meetcleo_production/blah', version_stage: 'CLEO-001' }).returns(
        {
          arn: 'arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3',
          name: 'meetcleo_production/blah',
          version_id: 'EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE',
          version_stages: [
            'AWSCURRENT'
          ]
        }
      )

      assert_equal 1, instance.add_version
    end

    private

    def instance
      described_class.new(secret:, client:) do |manager|
        manager.description = 'some description'
        manager.value = 'some value'
      end
    end

    attr_reader :secret, :client
  end
end
