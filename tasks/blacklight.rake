# frozen_string_literal: true

require 'engine_cart/rake_task'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

def with_solr
  puts "Starting Solr"
  system "docker-compose up -d solr"
  yield
ensure
  puts "Stopping Solr"
  system "docker-compose stop solr"
end

desc "Run test suite"
task :ci do
  with_solr do
    Rake::Task['engine_cart:generate'].invoke

    within_test_app do
      system "RAILS_ENV=test bin/rake blacklight:index:seed"
    end

    Rake::Task['blacklight:coverage'].invoke
  end
end

namespace :blacklight do
  desc "Run tests with coverage"
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task["spec"].invoke
  end

  namespace :internal do
    desc 'Index seed data in test ap'
    task :seed do
      Rake::Task['engine_cart:generate'].invoke unless File.exist?(EngineCart.destination)

      within_test_app do
        system "bin/rake blacklight:index:seed"
      end
    end
  end

  desc 'Run Solr and Blacklight for interactive development'
  task :server, [:rails_server_args] do |_t, args|
    with_solr do
      if File.exist? EngineCart.destination
        within_test_app do
          system "bundle update"
        end
      else
        Rake::Task['engine_cart:generate'].invoke
      end

      Rake::Task['blacklight:internal:seed'].invoke

      within_test_app do
        begin
          puts "Starting Blacklight (Rails server)"
          system "bin/rails s #{args[:rails_server_args]}"
        rescue Interrupt
          # We expect folks to Ctrl-c to stop the server so don't barf at them
          puts "\nStopping Blacklight (Rails server)"
        end
      end
    end
  end
end
