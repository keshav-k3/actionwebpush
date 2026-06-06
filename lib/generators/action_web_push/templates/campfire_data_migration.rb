# frozen_string_literal: true

class MigrateCampfirePushSubscriptionsToActionWebPush < ActiveRecord::Migration<%= migration_version %>
  def up
    # Create new ActionWebPush subscriptions table if it doesn't exist
    unless table_exists?(:action_web_push_subscriptions)
      create_table :action_web_push_subscriptions do |t|
        t.references :user, null: false, foreign_key: true
        t.string :endpoint, null: false
        t.string :p256dh_key, null: false
        t.string :auth_key, null: false
        t.string :user_agent
        t.timestamps null: false

        t.index [:user_id]
        t.index [:endpoint, :p256dh_key, :auth_key], name: "idx_action_web_push_subscription_keys"
      end
    end

    <% if preserve_data? %>
    # Migrate existing data
    if table_exists?(:<%= old_table_name %>)
      say "Migrating data from <%= old_table_name %> to action_web_push_subscriptions..."

      # Migrate in batches to avoid memory issues
      batch_size = 1000
      offset = 0

      loop do
        batch = connection.select_all(
          "SELECT * FROM <%= old_table_name %> LIMIT #{batch_size} OFFSET #{offset}"
        )

        break if batch.empty?

        batch.each do |record|
          # Map old columns to new columns
          new_record = {
            user_id: record['user_id'],
            endpoint: record['endpoint'],
            p256dh_key: record['p256dh_key'],
            auth_key: record['auth_key'],
            user_agent: record['user_agent'],
            created_at: record['created_at'] || Time.current,
            updated_at: record['updated_at'] || Time.current
          }

          # Insert with duplicate handling
          connection.execute(
            sanitize_sql_array([
              "INSERT INTO action_web_push_subscriptions (user_id, endpoint, p256dh_key, auth_key, user_agent, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT (endpoint, p256dh_key, auth_key) DO NOTHING",
              new_record[:user_id],
              new_record[:endpoint],
              new_record[:p256dh_key],
              new_record[:auth_key],
              new_record[:user_agent],
              new_record[:created_at],
              new_record[:updated_at]
            ])
          )
        end

        offset += batch_size
        say "Migrated batch #{offset / batch_size} (#{offset} total records)"
      end

      migrated_count = connection.select_value("SELECT COUNT(*) FROM action_web_push_subscriptions")
      original_count = connection.select_value("SELECT COUNT(*) FROM <%= old_table_name %>")

      say "Migration completed: #{migrated_count} records in new table, #{original_count} in original table"
    end
    <% end %>

    # Create a backup table for safety
    if table_exists?(:<%= old_table_name %>) && !table_exists?(:<%= old_table_name %>_backup)
      connection.execute("CREATE TABLE <%= old_table_name %>_backup AS SELECT * FROM <%= old_table_name %>")
      say "Created backup table: <%= old_table_name %>_backup"
    end
  end

  def down
    # Remove ActionWebPush table and restore from backup if needed
    drop_table :action_web_push_subscriptions if table_exists?(:action_web_push_subscriptions)

    if table_exists?(:<%= old_table_name %>_backup) && !table_exists?(:<%= old_table_name %>)
      connection.execute("CREATE TABLE <%= old_table_name %> AS SELECT * FROM <%= old_table_name %>_backup")
      say "Restored from backup table: <%= old_table_name %>_backup"
    end
  end

  private

  def sanitize_sql_array(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end