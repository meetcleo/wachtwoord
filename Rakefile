# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create

require 'rubocop/rake_task'

RuboCop::RakeTask.new

desc 'Performs sorbet type checking'
task :sorbet do
  `srb tc`
end

task default: %i[test rubocop sorbet]
