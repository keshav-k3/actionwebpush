# frozen_string_literal: true

class CreateActionWebPushSubscriptions < ActiveRecord::Migration<%= migration_version %>
  def change
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
end