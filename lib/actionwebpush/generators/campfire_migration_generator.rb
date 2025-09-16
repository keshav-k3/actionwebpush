# frozen_string_literal: true

require "rails/generators/base"

module ActionWebPush
  module Generators
    class CampfireMigrationGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Generate migration from Campfire's existing push_subscriptions to ActionWebPush"

      class_option :table_name, type: :string, default: "push_subscriptions",
                   desc: "Name of existing Campfire table"

      class_option :preserve_data, type: :boolean, default: true,
                   desc: "Whether to preserve existing subscription data"

      def create_data_migration
        template(
          "campfire_data_migration.rb",
          "db/migrate/#{timestamp}_migrate_campfire_push_subscriptions_to_action_web_push.rb",
          migration_version: migration_version
        )
      end

      def create_compatibility_module
        template(
          "campfire_compatibility.rb",
          "lib/action_web_push/campfire_compatibility.rb"
        )
      end

      def show_migration_instructions
        say "\n" + "="*70
        say "Campfire to ActionWebPush Migration Generated!"
        say "="*70
        say "\nNext steps:"
        say "1. Review the generated migration file"
        say "2. Backup your existing push_subscriptions data"
        say "3. Run: rails db:migrate"
        say "4. Update your Campfire code to use ActionWebPush"
        say "5. Test thoroughly in staging environment"
        say "\nCompatibility module created at: lib/action_web_push/campfire_compatibility.rb"
        say "This provides backward compatibility during the transition period."
        say "\nIMPORTANT: Test this migration on a copy of production data first!"
      end

      private

      def timestamp
        Time.current.strftime("%Y%m%d%H%M%S")
      end

      def migration_version
        if Rails::VERSION::MAJOR >= 5
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end

      def old_table_name
        options[:table_name]
      end

      def preserve_data?
        options[:preserve_data]
      end
    end
  end
end