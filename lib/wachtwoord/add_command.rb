# typed: true
# frozen_string_literal: true

module Wachtwoord
  # The CLI flow behind `rake secret:add`. Interactive when stdin is a TTY
  # (same prompts as always); when stdin is piped it skips the prompts and
  # reads the value from stdin until EOF, so the task can be scripted:
  #
  #   printf '%s' "$VALUE" | rake secret:add['name_of_secret','description']
  class AddCommand
    extend T::Sig

    class NotConfirmedError < StandardError; end
    class EmptyValueError < StandardError; end

    sig { params(name: String, description: T.nilable(String), stdin: T.untyped, stdout: T.untyped).void }
    def initialize(name:, description: nil, stdin: $stdin, stdout: $stdout)
      @name = name
      @description = description
      @stdin = stdin
      @stdout = stdout
      @interactive = T.let(stdin.tty?, T::Boolean)
    end

    sig { returns([String, Integer]) }
    def run
      Wachtwoord.add_or_update(name:) do |manager|
        announce(existing: manager.existing_secret?)

        value = read_value
        raise EmptyValueError, 'Empty secret value on stdin' if value.empty?

        manager.value = value
        manager.description = resolve_description unless manager.existing_secret?
        manager
      end
    end

    private

    attr_reader :name, :stdin, :stdout, :interactive

    sig { params(existing: T::Boolean).void }
    def announce(existing:)
      unless interactive
        action = existing ? 'already exists, adding a new version' : 'does not exist, creating it'
        stdout.puts "Secret called `#{name}` #{action} (non-interactive, reading the value from stdin)"
        return
      end

      if existing
        stdout.puts "Secret called `#{name}` already exists, would you like to add a new version? (y/n)>"
      else
        stdout.puts "Secret called `#{name}` does not exist, would you like to create it? (y/n)>"
      end

      raise NotConfirmedError, 'Did not get a yes' if stdin.gets.strip.downcase != 'y'

      stdout.puts 'Paste your secret below.'
      stdout.puts 'Press Ctrl+D when finished.'
      stdout.puts 'Enter the secret value>'
    end

    sig { returns(String) }
    def read_value
      stdin.read.strip
    end

    sig { returns(String) }
    def resolve_description
      return T.must(@description) if @description

      unless interactive
        # No way to prompt after stdin hit EOF; store an empty description.
        return ''
      end

      stdout.puts 'Add an optional description>'
      stdin.gets.chomp
    end
  end
end
