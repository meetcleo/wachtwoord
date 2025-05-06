# typed: true
# frozen_string_literal: true

module Wachtwoord
  class SecretNameMatcher
    extend T::Sig
    class << self
      extend T::Sig
      sig { params(token: String).returns(Regexp) }
      def token_to_pattern(token)
        /(\b|_)(#{token})(\b|_)/i
      end
    end

    def initialize
      @secret_name_patterns = Wachtwoord.configuration.secret_name_tokens.map { |token| self.class.token_to_pattern(token) }
      @normalized_allowed_config_names = Wachtwoord.configuration.allowed_config_names.map(&:downcase)
      @secret_version_env_name_prefix = Wachtwoord.configuration.secret_version_env_name_prefix.downcase
    end

    sig { params(name: T.nilable(String)).returns(T::Boolean) }
    def secret_name?(name)
      return false if name.nil?

      normalized_name = name.strip.downcase
      return false if normalized_name.start_with?(secret_version_env_name_prefix)
      return false if normalized_allowed_config_names.include?(normalized_name)

      secret_name_patterns.any? { |secret_name_pattern| normalized_name.match(secret_name_pattern) }
    end

    private

    sig { returns(T::Array[Regexp]) }
    attr_reader :secret_name_patterns

    sig { returns(T::Array[String]) }
    attr_reader :normalized_allowed_config_names

    sig { returns(String) }
    attr_reader :secret_version_env_name_prefix
  end
end
