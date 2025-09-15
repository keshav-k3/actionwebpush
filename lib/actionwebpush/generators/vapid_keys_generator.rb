# frozen_string_literal: true

require "rails/generators/base"
require "web-push"

module ActionWebPush
  module Generators
    class VapidKeysGenerator < Rails::Generators::Base
      desc "Generate VAPID key pair for Web Push notifications"

      def generate_vapid_keys
        vapid_key = WebPush.generate_key

        say "Generated VAPID key pair:"
        say "========================="
        say ""
        say "Add these to your environment variables or Rails credentials:"
        say ""
        say "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
        say "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
        say ""
        say "Or add to config/credentials.yml.enc:"
        say ""
        say "action_web_push:"
        say "  vapid_public_key: #{vapid_key.public_key}"
        say "  vapid_private_key: #{vapid_key.private_key}"
        say ""
        say "Then update your config/initializers/action_web_push.rb:"
        say ""
        say "ActionWebPush.configure do |config|"
        say "  config.vapid_public_key = Rails.application.credentials.action_web_push[:vapid_public_key]"
        say "  config.vapid_private_key = Rails.application.credentials.action_web_push[:vapid_private_key]"
        say "  # ... other config"
        say "end"
      end
    end
  end
end