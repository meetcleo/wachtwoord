# typed: true
# frozen_string_literal: true

namespace :secret do
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
    end

    puts "Add the following to your .env.x file to use this version: #{secret_env}=#{version_number}"
  end
end
