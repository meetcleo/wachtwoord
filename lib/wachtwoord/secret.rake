# typed: true
# frozen_string_literal: true

namespace :secret do
  desc "Creates a secret or adds a version to an existing secret, rake secret:add['name_of_secret']. " \
       'With piped stdin (non-interactive) the value is read from stdin until EOF, prompts are ' \
       "skipped, and the description may be passed as a second arg: rake secret:add['name','description']"
  task :add, %i[name_of_secret description] => :environment do |_t, args|
    raise 'We only store secrets in secrets manager for production and staging' unless Rails.env.production?

    secret_env, version_number = Wachtwoord::AddCommand.new(name: args[:name_of_secret], description: args[:description]).run

    puts "Add the following to your .env.x file to use this version: #{secret_env}=#{version_number}"
  rescue Wachtwoord::AddCommand::NotConfirmedError
    abort 'Did not get a yes, aborting'.red
  rescue Wachtwoord::AddCommand::EmptyValueError
    abort 'Empty secret value, aborting'.red
  end

  desc 'Creates a secret or adds a version to an existing secret, rake secret:import_from_heroku[cleo-staging-private,.env.staging,false]'
  task :import_from_heroku, %i[application_name dotenv_file_path overwrite] => :environment do |_t, args|
    raise 'Importing is done from dev CLI' unless Rails.env.development?

    application_name = args[:application_name]
    dotenv_file_path = args[:dotenv_file_path]
    overwrite = args[:overwrite] == 'true'
    imported_keys = Wachtwoord::Import.from_heroku(application_name:, dotenv_file_path:, overwrite:)

    puts 'Imported these ENVs...'
    puts imported_keys.join("\n")
    puts "Wrote configs to: #{dotenv_file_path}. Secrets to: https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1&search=name%3D#{application_name}"
  end
end
