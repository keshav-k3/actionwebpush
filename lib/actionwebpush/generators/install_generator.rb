# frozen_string_literal: true

require "rails/generators/base"

module ActionWebPush
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_migration
        migration_template(
          "create_action_web_push_subscriptions.rb",
          "db/migrate/create_action_web_push_subscriptions.rb",
          migration_version: migration_version
        )
      end

      def create_initializer
        template "initializer.rb", "config/initializers/action_web_push.rb"
      end

      def mount_engine
        route "mount ActionWebPush::Engine => '/push'"
      end

      def show_readme
        say "\n" + "="*50
        say "ActionWebPush has been installed!"
        say "="*50
        say "\nNext steps:"
        say "1. Run: rails db:migrate"
        say "2. Configure VAPID keys in config/initializers/action_web_push.rb"
        say "3. Add 'has_many :push_subscriptions, class_name: \"ActionWebPush::Subscription\"' to your User model"
        say "4. Generate VAPID keys with: bundle exec rails generate action_web_push:vapid_keys"
        say "\nFor more information, visit: https://github.com/yourusername/actionwebpush"
      end

      private

      def migration_version
        if Rails::VERSION::MAJOR >= 5
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end
    end
  end
end