# typed: true
# frozen_string_literal: true

# Adds a secret version in secrets manager.
# Adds a 'version stage' the new secret version with an incrementing Cleo version number.
# This enables us to add new versions without making them 'live' for the application.
# More info in: https://docs.aws.amazon.com/secretsmanager/latest/userguide/whats-in-a-secret.html#term_version

module Wachtwoord
  class Manager
    extend T::Sig
    SECRET_KEY = :value

    sig { params(secret: Secret, client: T.untyped).void }
    def initialize(secret:, client:)
      @secret = secret
      @client = client
      yield self
    end

    sig { returns(T::Boolean) }
    def existing_secret?
      list_secret_version_ids.any?
    end

    sig { returns(Integer) }
    def add_version
      secret_hash = if existing_secret?
                      put_secret_value
                    else
                      create_secret
                    end

      update_secret_version_stage(move_to_version_id: secret_hash[:version_id])

      version_stage.version_number
    end

    sig { returns(String) }
    attr_accessor :value

    sig { returns(String) }
    attr_accessor :description

    private

    sig { returns(T.untyped) }
    attr_reader :client

    sig { returns(Secret) }
    attr_reader :secret

    sig { returns(String) }
    def name
      secret.namespaced_name
    end
    alias secret_id name

    sig { returns(String) }
    def secret_string
      @secret_string ||= { SECRET_KEY => value }.to_json
    end

    sig { returns(VersionStage) }
    def version_stage
      @version_stage ||= previous_version_stage&.next_version_stage || Wachtwoord::VersionStage.first_version_stage
    end

    sig { returns(T.nilable(VersionStage)) }
    def previous_version_stage
      return unless existing_secret?

      @previous_version_stage ||= list_secret_version_ids[:versions]
                                  .flat_map { |version| Wachtwoord::VersionStage.find_first(serialized_version_stages: version[:version_stages]) }
                                  .compact
                                  .max
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#create_secret-instance_method
    # resp.to_h outputs the following:
    # {
    #   arn: "arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3",
    #   name: "MyTestDatabaseSecret",
    #   version_id: "EXAMPLE1-90ab-cdef-fedc-ba987SECRET1",
    # }
    sig { returns(Hash) }
    def create_secret
      client.create_secret({
                             name:,
                             secret_string:,
                             description:
                           }).to_h
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#put_secret_value-instance_method
    # resp.to_h outputs the following:
    # {
    #   arn: "arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3",
    #   name: "MyTestDatabaseSecret",
    #   version_id: "EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE",
    #   version_stages: [
    #     "AWSCURRENT",
    #   ],
    # }
    sig { returns(Hash) }
    def put_secret_value
      client.put_secret_value({
                                secret_id:,
                                secret_string:
                              }).to_h
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#list_secret_version_ids-instance_method
    # resp.to_h outputs the following:
    # {
    #   arn: "arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3",
    #   name: "MyTestDatabaseSecret",
    #   versions: [
    #     {
    #       created_date: Time.parse(1523477145.713),
    #       version_id: "EXAMPLE1-90ab-cdef-fedc-ba987EXAMPLE",
    #       version_stages: [
    #         "AWSPREVIOUS",
    #       ],
    #     },
    #     {
    #       created_date: Time.parse(1523486221.391),
    #       version_id: "EXAMPLE2-90ab-cdef-fedc-ba987EXAMPLE",
    #       version_stages: [
    #         "AWSCURRENT",
    #       ],
    #     },
    #     {
    #       created_date: Time.parse(1511974462.36),
    #       version_id: "EXAMPLE3-90ab-cdef-fedc-ba987EXAMPLE;",
    #     },
    #   ],
    # }

    sig { returns(Hash) }
    def list_secret_version_ids
      @list_secret_version_ids ||= begin
        client.list_secret_version_ids({
                                         secret_id:
                                       }).to_h
      rescue ::Aws::SecretsManager::Errors::ResourceNotFoundException
        {}
      end
    end

    # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#update_secret_version_stage-instance_method
    # resp.to_h outputs the following:
    # {
    #   arn: "arn:aws:secretsmanager:us-west-2:123456789012:secret:MyTestDatabaseSecret-a1b2c3",
    #   name: "MyTestDatabaseSecret",
    # }
    sig { params(move_to_version_id: String).returns(Hash) }
    def update_secret_version_stage(move_to_version_id:)
      client.update_secret_version_stage({
                                           move_to_version_id:,
                                           secret_id:,
                                           version_stage: version_stage.serialized_version_stage
                                         }).to_h
    end
  end
end
