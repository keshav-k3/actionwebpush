# frozen_string_literal: true

ActionWebPush.configure do |config|
  # VAPID keys for Web Push notifications
  # Generate with: bundle exec rails generate action_web_push:vapid_keys
  config.vapid_public_key = ENV['VAPID_PUBLIC_KEY']
  config.vapid_private_key = ENV['VAPID_PRIVATE_KEY']
  config.vapid_subject = 'mailto:support@example.com'

  # Thread pool configuration
  config.pool_size = 50
  config.queue_size = 10000

  # Delivery method
  config.delivery_method = :web_push
end