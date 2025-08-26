# typed: true
# frozen_string_literal: true

# TODO
module Wachtwoord
  class Secret
    extend Forwardable
    extend T::Sig
    include Comparable

    NAMESPACE_SEPARATOR = '/'
    class NilSecretName < StandardError; end

    class << self
      extend T::Sig

      sig { returns(T.nilable(String)) }
      def namespace
        Wachtwoord.configuration.secrets_namespace
      end

      sig { returns(String) }
      def version_env_name_prefix
        Wachtwoord.configuration.secret_version_env_name_prefix
      end

      sig { params(name: String, override_namespace: T.nilable(String)).returns(String) }
      def namespaced_name(name:, override_namespace:)
        [override_namespace || namespace, name.downcase].join(NAMESPACE_SEPARATOR)
      end

      sig { params(name: String).returns(String) }
      def prefixed_name(name:)
        "#{version_env_name_prefix}#{name.upcase}"
      end

      sig { params(prefixed_name: T.nilable(String)).returns(T.nilable(String)) }
      def name_without_prefix(prefixed_name:)
        prefixed_name&.gsub(version_env_name_prefix, '')&.downcase
      end

      sig { params(namespaced_name: T.nilable(String)).returns(T.nilable(String)) }
      def name_without_namespace(namespaced_name:)
        namespaced_name&.split(NAMESPACE_SEPARATOR)&.last
      end

      sig { params(prefixed_name: String).returns(T.nilable(Secret)) }
      def try_parse(prefixed_name:)
        return unless prefixed_name.start_with?(version_env_name_prefix)

        new(prefixed_name:)
      end
    end

    sig { params(name: T.nilable(String), prefixed_name: T.nilable(String), namespaced_name: T.nilable(String), override_namespace: T.nilable(String)).void }
    def initialize(name: nil, prefixed_name: nil, namespaced_name: nil, override_namespace: nil)
      @name = name || self.class.name_without_prefix(prefixed_name:) || self.class.name_without_namespace(namespaced_name:)
      raise NilSecretName if @name.nil?

      @prefixed_name = prefixed_name || self.class.prefixed_name(name: @name)
      @namespaced_name = namespaced_name || self.class.namespaced_name(name: @name, override_namespace:)
    end

    sig { params(other: Secret).returns(T.nilable(Integer)) }
    def <=>(other)
      name <=> other.name
    end

    sig { params(other: Secret).returns(T::Boolean) }
    def eql?(other)
      name.eql?(other.name)
    end

    sig { returns(String) }
    def env_name
      name.upcase
    end

    def_delegator :@name, :hash

    sig { returns(String) }
    attr_reader :name

    sig { returns(String) }
    attr_reader :prefixed_name

    sig { returns(String) }
    attr_reader :namespaced_name
  end
end
