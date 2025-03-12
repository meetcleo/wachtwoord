# typed: false
# frozen_string_literal: true

require 'test_helper'

class TestWachtwoord < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil described_class::VERSION
  end

  def test_that_it_has_a_configuration
    refute_nil described_class.configuration
  end
end
