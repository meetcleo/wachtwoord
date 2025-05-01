# frozen_string_literal: true

require_relative 'lib/wachtwoord/version'

Gem::Specification.new do |spec|
  spec.name = 'wachtwoord'
  spec.version = Wachtwoord::VERSION
  spec.authors = ['Josh Fleck']
  spec.email = ['josh@meetcleo.com']

  spec.summary = 'Gem for managing secrets and their versions'
  spec.homepage = 'https://github.com/meetcleo/wachtwoord'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/meetcleo/wachtwoord'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-secretsmanager', '~> 1.0'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'sorbet-runtime'
end
