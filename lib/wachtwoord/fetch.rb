# typed: true
# frozen_string_literal: true

# Batch-fetches secret values from SecretsManager
# Note that batch-fetching only allows you to fetch the
# secret at the current version stage, so for secrets
# where we still desire a previous version stage, we
# need to fetch them one-by-one.
module Wachtwoord
  class Fetch
    extend T::Sig
    class MissingSecretsError < StandardError; end
    class AdditionalSecretsError < StandardError; end
    class FetchingSecretsError < StandardError; end
    MAX_SECRETS_PER_FETCH = 20 # Limit imposed by AWS
    RESOURCE_NOT_FOUND_ERROR_CLASS_NAME = 'ResourceNotFoundException'
    MISSING_SECRET_PLACEHOLDER = { secret_string: { Wachtwoord::Manager::SECRET_KEY => '' }.to_json }.freeze

    sig { params(desired_version_stages_by_secret: T::Hash[Secret, VersionStage], client: T.untyped, raise_if_not_found: T.nilable(T::Boolean)).void }
    def initialize(desired_version_stages_by_secret:, client:, raise_if_not_found: true)
      @client = client
      @desired_version_stages_by_secret = desired_version_stages_by_secret
      @raise_if_not_found = T.must(raise_if_not_found)
    end

    sig { returns(T::Hash[String, String]) }
    def secret_values_by_env_name
      current_version_secrets = fetch_paged_current_version_stage_secrets(remaining_secret_id_list: secret_id_list)
      current_version_secrets.to_h do |current_version_secret|
        secret_value_pair(current_version_secret)
      end
    end

    private

    sig { returns(T::Array[String]) }
    def secret_id_list
      desired_version_stages_by_secret.keys.map(&:namespaced_name)
    end

    sig { params(current_version_secret: T::Hash[Symbol, T.untyped]).returns([String, String]) }
    def secret_value_pair(current_version_secret)
      secret = Wachtwoord::Secret.new(namespaced_name: current_version_secret[:name])
      current_version_stage = Wachtwoord::VersionStage.find_first(serialized_version_stages: current_version_secret[:version_stages])
      desired_version_stage = T.must(desired_version_stages_by_secret[secret])

      unless current_version_stage
        Wachtwoord.configuration.logger.warn("[Wachtwoord] Version stage missing for secret named: #{secret.name}. It could indicate adding/updating partially failed.")
        current_version_stage = desired_version_stage
      end

      env_name = secret.env_name
      return [env_name, secret_value(current_version_secret[:secret_string])] if desired_version_stage == VersionStage.newest_version_stage || desired_version_stage == current_version_stage

      desired_version_secret = fetch_secret_at_version_stage(secret:, version_stage: desired_version_stage)
      [env_name, secret_value(desired_version_secret[:secret_string])]
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#batch_get_secret_value-instance_method
    # resp.to_h outputs the following:
    # {
    #   errors: [
    #   ],
    #   secret_values: [
    #     {
    #       arn: "&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret1-a1b2c3",
    #       created_date: Time.parse(1700591229.801),
    #       name: "MySecret1",
    #       secret_string: "{\"username\":\"diego_ramirez\",\"password\":\"EXAMPLE-PASSWORD\",\"engine\":\"mysql\",\"host\":\"secretsmanagertutorial.cluster.us-west-2.rds.amazonaws.com\",\"port\":3306,\"dbClusterIdentifier\":\"secretsmanagertutorial\"}",
    #       version_id: "a1b2c3d4-5678-90ab-cdef-EXAMPLEaaaaa",
    #       version_stages: [
    #         "AWSCURRENT",
    #       ],
    #     },
    #     {
    #       arn: "&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret2-a1b2c3",
    #       created_date: Time.parse(1699911394.105),
    #       name: "MySecret2",
    #       secret_string: "{\"username\":\"akua_mansa\",\"password\":\"EXAMPLE-PASSWORD\"",
    #       version_id: "a1b2c3d4-5678-90ab-cdef-EXAMPLEbbbbb",
    #       version_stages: [
    #         "AWSCURRENT",
    #       ],
    #     },
    #     {
    #       arn: "&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret3-a1b2c3",
    #       created_date: Time.parse(1699911394.105),
    #       name: "MySecret3",
    #       secret_string: "{\"username\":\"jie_liu\",\"password\":\"EXAMPLE-PASSWORD\"",
    #       version_id: "a1b2c3d4-5678-90ab-cdef-EXAMPLEccccc",
    #       version_stages: [
    #         "AWSCURRENT",
    #       ],
    #     },
    #   ],
    # }
    sig { params(remaining_secret_id_list: T::Array[String], secret_values: T.nilable(T::Array[T::Hash[Symbol, T.untyped]])).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def fetch_paged_current_version_stage_secrets(remaining_secret_id_list:, secret_values: [])
      secret_values = T.must(secret_values)
      return secret_values if remaining_secret_id_list.empty?

      response = client.batch_get_secret_value({
                                                 secret_id_list: remaining_secret_id_list.pop(MAX_SECRETS_PER_FETCH)
                                               }).to_h
      validate_response!(response)
      fetch_paged_current_version_stage_secrets(remaining_secret_id_list:, secret_values: secret_values + response[:secret_values])
    end

    sig { params(response: T.untyped).void }
    def validate_response!(response)
      raise AdditionalSecretsError, 'A `next_token` was provided in the response indicating there is more data to fetch, but we do not support this' if response[:next_token]

      not_found_errors = response[:errors].select { |error| error[:error_code] == RESOURCE_NOT_FOUND_ERROR_CLASS_NAME }
      other_errors = response[:errors].reject { |error| error[:error_code] == RESOURCE_NOT_FOUND_ERROR_CLASS_NAME }
      raise FetchingSecretsError, "errors from secrets manager API: #{other_errors}" if other_errors.any?

      return unless not_found_errors.any?

      missing_secrets_message = "couldn't find some secrets: #{not_found_errors}"
      raise MissingSecretsError, missing_secrets_message if raise_if_not_found

      Wachtwoord.configuration.logger.warn("[Wachtwoord] #{missing_secrets_message}")
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#get_secret_value-instance_method
    # resp.to_h outputs the following:
    # {
    #   arn: "arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3",
    #   created_date: Time.parse(1523477145.713),
    #   name: "MyTestDatabaseSecret",
    #   secret_string: "{\n  \"username\":\"david\",\n  \"password\":\"EXAMPLE-PASSWORD\"\n}\n",
    #   version_id: "EXAMPLE1-90ab-cdef-fedc-ba987SECRET1",
    #   version_stages: [
    #     "AWSPREVIOUS",
    #   ],
    # }
    sig { params(secret: Secret, version_stage: VersionStage).returns(T::Hash[Symbol, T.untyped]) }
    def fetch_secret_at_version_stage(secret:, version_stage:)
      client.get_secret_value({
                                secret_id: secret.namespaced_name,
                                version_stage: version_stage.serialized_version_stage
                              }).to_h
    rescue ::Aws::SecretsManager::Errors::ResourceNotFoundException
      missing_secrets_message = "unable to find #{secret.namespaced_name} at version stage #{version_stage.serialized_version_stage} in secrets manager"
      raise MissingSecretsError, missing_secrets_message if raise_if_not_found

      Wachtwoord.configuration.logger.warn("[Wachtwoord] #{missing_secrets_message}")
      MISSING_SECRET_PLACEHOLDER
    end

    sig { params(secret_string: String).returns(String) }
    def secret_value(secret_string)
      JSON.parse(secret_string)[Wachtwoord::Manager::SECRET_KEY.to_s]
    end

    sig { returns(T::Hash[Secret, VersionStage]) }
    attr_reader :desired_version_stages_by_secret

    sig { returns(T.untyped) }
    attr_reader :client

    sig { returns(T::Boolean) }
    attr_reader :raise_if_not_found
  end
end
