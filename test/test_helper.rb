# typed: false
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'tapioca'
require 'wachtwoord'

require 'minitest/hooks'
require 'mocha/minitest'
require 'minitest/autorun'

module Minitest
  class Test
    include Minitest::Hooks

    around do |&block|
      Wachtwoord.reset
      super(&block)
    end

    private

    def described_class
      Object.const_get(self.class.name.sub(/\bTest/, '')) # rubocop:disable Sorbet/ConstantsFromStrings
    end
  end
end
