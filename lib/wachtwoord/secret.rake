# typed: true
# frozen_string_literal: true

namespace :secret do # rubocop:disable Metrics/BlockLength
  desc "Creates a secret or adds a version to an existing secret, rake secret:add['name_of_secret']"
  task :add, [:name_of_secret] => :environment do |_t, args|
    raise 'We only store secrets in secrets manager for production and staging' unless Rails.env.production?

    name = args[:name_of_secret]
    secret_env, version_number = Wachtwoord.add_or_update(name:) do |manager|
      if manager.existing_secret?
        puts "Secret called `#{name}` already exists, would you like to add a new version? (y/n)>"
      else
        puts "Secret called `#{name}` does not exist, would you like to create it? (y/n)>"
      end

      abort 'Did not get a yes, aborting'.red if $stdin.gets.strip.downcase != 'y'

      puts 'Enter the secret value>'
      manager.value = $stdin.gets.chomp

      unless manager.existing_secret?
        puts 'Add an optional description>'
        manager.description = $stdin.gets.chomp
      end
      manager
    end

    puts "Add the following to your .env.x file to use this version: #{secret_env}=#{version_number}"
  end

  desc 'Creates a secret or adds a version to an existing secret, rake secret:import_from_heroku[cleo-staging-private,.env.staging,false]'
  task :import_from_heroku, %i[application_name dotenv_file_path overwrite] => :environment do |_t, args|
    raise 'Importing is done from dev CLI' unless Rails.env.development?

    application_name = args[:application_name]
    dotenv_file_path = args[:dotenv_file_path]
    overwrite = args[:overwrite] == 'true'
    Wachtwoord::Import.from_heroku(application_name:, dotenv_file_path:, overwrite:)

    puts "Wrote configs to: #{dotenv_file_path}. Secrets to: https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1&search=name%3D#{application_name}"
  end
end
