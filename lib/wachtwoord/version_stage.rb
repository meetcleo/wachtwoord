# typed: true
# frozen_string_literal: true

module Wachtwoord
  class VersionStage
    include Comparable
    extend T::Sig

    class << self
      extend T::Sig

      sig { params(version_number: T.nilable(Integer)).returns(String) }
      def serialized_version_stage(version_number:)
        "#{Wachtwoord.configuration.version_stage_prefix}#{version_number.to_s.rjust(3, '0')}"
      end

      sig { params(serialized_version_stage: T.nilable(String)).returns(T.nilable(String)) }
      def version_number(serialized_version_stage:)
        serialized_version_stage&.gsub(Wachtwoord.configuration.version_stage_prefix, '')
      end

      sig { params(serialized_version_stage: String).returns(T.nilable(VersionStage)) }
      def try_parse(serialized_version_stage:)
        return unless serialized_version_stage.start_with?(Wachtwoord.configuration.version_stage_prefix)

        new(serialized_version_stage:)
      end

      sig { params(serialized_version_stages: T::Array[String]).returns(T.nilable(VersionStage)) }
      def find_first(serialized_version_stages:)
        serialized_version_stages.filter_map { |serialized_version_stage| try_parse(serialized_version_stage:) }.first
      end

      sig { returns(VersionStage) }
      def first_version_stage
        new(version_number: 1)
      end

      sig { returns(VersionStage) }
      def newest_version_stage
        new(version_number: -1)
      end
    end

    sig { params(serialized_version_stage: T.nilable(String), version_number: T.nilable(Integer)).void }
    def initialize(serialized_version_stage: nil, version_number: nil)
      @serialized_version_stage = serialized_version_stage || self.class.serialized_version_stage(version_number:)
      @version_number = (version_number || self.class.version_number(serialized_version_stage: @serialized_version_stage)).to_i
    end

    sig { returns(String) }
    attr_reader :serialized_version_stage

    sig { returns(Integer) }
    attr_reader :version_number

    sig { returns(VersionStage) }
    def next_version_stage
      self.class.new(version_number: version_number + 1)
    end

    sig { params(other: VersionStage).returns(T.nilable(Integer)) }
    def <=>(other)
      version_number <=> other.version_number
    end
  end
end
