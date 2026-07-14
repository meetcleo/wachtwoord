# typed: false
# frozen_string_literal: true

require 'test_helper'
require 'stringio'

module Wachtwoord
  module Commands
    class TestAdd < Minitest::Test
      def setup
        @stdout = StringIO.new
        @manager = mock(:manager)
      end

      def test_non_interactive_create_with_description
        @manager.stubs(:existing_secret?).returns(false)
        @manager.expects(:value=).with('the-value')
        @manager.expects(:description=).with('the description')
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager).returns(['SECRET_VERSION_ENV_BLAH', 1])

        result = described_class.new(name: 'blah', description: 'the description', stdin: StringIO.new('the-value'), stdout: @stdout).run

        assert_equal ['SECRET_VERSION_ENV_BLAH', 1], result
        assert_includes @stdout.string, 'does not exist, creating it (non-interactive'
      end

      def test_non_interactive_create_without_description_stores_empty_description
        @manager.stubs(:existing_secret?).returns(false)
        @manager.expects(:value=).with('the-value')
        @manager.expects(:description=).with('')
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager).returns(['SECRET_VERSION_ENV_BLAH', 1])

        described_class.new(name: 'blah', stdin: StringIO.new('the-value'), stdout: @stdout).run
      end

      def test_non_interactive_add_version_skips_description
        @manager.stubs(:existing_secret?).returns(true)
        @manager.expects(:value=).with('v2-value')
        @manager.expects(:description=).never
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager).returns(['SECRET_VERSION_ENV_BLAH', 2])

        described_class.new(name: 'blah', stdin: StringIO.new("v2-value\n"), stdout: @stdout).run

        assert_includes @stdout.string, 'already exists, adding a new version (non-interactive'
      end

      def test_empty_value_raises
        @manager.stubs(:existing_secret?).returns(false)
        @manager.expects(:value=).never
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager)

        assert_raises(described_class::EmptyValueError) do
          described_class.new(name: 'blah', stdin: StringIO.new("  \n"), stdout: @stdout).run
        end
      end

      def test_interactive_create_prompts_for_confirmation_value_and_description
        stdin = mock(:stdin)
        stdin.stubs(:tty?).returns(true)
        stdin.stubs(:gets).returns("y\n", "typed description\n")
        stdin.stubs(:read).returns("typed-value\n")

        @manager.stubs(:existing_secret?).returns(false)
        @manager.expects(:value=).with('typed-value')
        @manager.expects(:description=).with('typed description')
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager).returns(['SECRET_VERSION_ENV_BLAH', 1])

        described_class.new(name: 'blah', stdin:, stdout: @stdout).run

        assert_includes @stdout.string, 'would you like to create it? (y/n)>'
        assert_includes @stdout.string, 'Add an optional description>'
      end

      def test_interactive_description_arg_skips_description_prompt
        stdin = mock(:stdin)
        stdin.stubs(:tty?).returns(true)
        stdin.stubs(:gets).returns("y\n")
        stdin.stubs(:read).returns('typed-value')

        @manager.stubs(:existing_secret?).returns(false)
        @manager.expects(:value=).with('typed-value')
        @manager.expects(:description=).with('arg description')
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager).returns(['SECRET_VERSION_ENV_BLAH', 1])

        described_class.new(name: 'blah', description: 'arg description', stdin:, stdout: @stdout).run

        refute_includes @stdout.string, 'Add an optional description>'
      end

      def test_interactive_not_confirmed_raises
        stdin = mock(:stdin)
        stdin.stubs(:tty?).returns(true)
        stdin.stubs(:gets).returns("n\n")

        @manager.stubs(:existing_secret?).returns(true)
        @manager.expects(:value=).never
        Wachtwoord.expects(:add_or_update).with(name: 'blah').yields(@manager)

        assert_raises(described_class::NotConfirmedError) do
          described_class.new(name: 'blah', stdin:, stdout: @stdout).run
        end

        assert_includes @stdout.string, 'already exists, would you like to add a new version? (y/n)>'
      end
    end
  end
end
