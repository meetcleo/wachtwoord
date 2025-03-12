# typed: false
# frozen_string_literal: true

require 'test_helper'

module Wachtwoord
  class TestVersionStage < Minitest::Test
    def test_serialized_version_stage
      assert_equal 'CLEO-000', described_class.serialized_version_stage(version_number: nil)
      assert_equal 'CLEO-001', described_class.serialized_version_stage(version_number: 1)
      assert_equal 'CLEO-100', described_class.serialized_version_stage(version_number: 100)
    end

    def test_version_number
      assert_nil described_class.version_number(serialized_version_stage: nil)
      assert_equal '000', described_class.version_number(serialized_version_stage: 'CLEO-000')
      assert_equal '001', described_class.version_number(serialized_version_stage: 'CLEO-001')
      assert_equal '100', described_class.version_number(serialized_version_stage: 'CLEO-100')
    end

    def test_try_parse
      assert_nil described_class.try_parse(serialized_version_stage: 'blah')
      assert_equal described_class.new(version_number: 0), described_class.try_parse(serialized_version_stage: 'CLEO-000')
      assert_equal described_class.new(version_number: 1), described_class.try_parse(serialized_version_stage: 'CLEO-001')
      assert_equal described_class.new(version_number: 100), described_class.try_parse(serialized_version_stage: 'CLEO-100')
    end

    def test_find_first
      assert_nil described_class.find_first(serialized_version_stages: ['blah'])
      assert_equal described_class.new(version_number: 0), described_class.find_first(serialized_version_stages: %w[blah CLEO-000 CLEO-001 blah])
    end

    def test_first_version_stage
      assert_equal described_class.new(version_number: 1), described_class.first_version_stage
    end

    def test_new
      assert_equal described_class.new(version_number: 1), described_class.new(version_number: 1)
      assert_equal described_class.new(version_number: 1), described_class.new(serialized_version_stage: 'CLEO-001')
      assert_equal 1, described_class.new(serialized_version_stage: 'CLEO-001').version_number
      assert_equal 'CLEO-001', described_class.new(version_number: 1).serialized_version_stage
    end

    def test_next_version_stage
      assert_equal described_class.new(version_number: 2), described_class.new(version_number: 1).next_version_stage
    end
  end
end
