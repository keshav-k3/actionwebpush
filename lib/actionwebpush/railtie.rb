# frozen_string_literal: true

require "rails/railtie"

module ActionWebPush
  class Railtie < ::Rails::Railtie
    config.action_web_push = ActiveSupport::OrderedOptions.new

    initializer "action_web_push.set_configs" do |app|
      options = app.config.action_web_push

      ActionWebPush.configure do |config|
        config.vapid_public_key = options.vapid_public_key if options.vapid_public_key
        config.vapid_private_key = options.vapid_private_key if options.vapid_private_key
        config.vapid_subject = options.vapid_subject if options.vapid_subject
        config.pool_size = options.pool_size if options.pool_size
        config.queue_size = options.queue_size if options.queue_size
        config.delivery_method = options.delivery_method if options.delivery_method
      end
    end

    initializer "action_web_push.initialize_pool" do |app|
      app.config.x.action_web_push_pool = ActionWebPush::Pool.new(
        invalid_subscription_handler: ->(subscription_id) do
          Rails.application.executor.wrap do
            Rails.logger.info "Destroying push subscription: #{subscription_id}"
            ActionWebPush::Subscription.find_by(id: subscription_id)&.destroy
          end
        end
      )

      at_exit { app.config.x.action_web_push_pool.shutdown }
    end

    initializer "action_web_push.set_autoload_paths" do |app|
      models_path = File.expand_path("../../app/models", __dir__)
      controllers_path = File.expand_path("../../app/controllers", __dir__)

      unless app.config.autoload_paths.include?(models_path)
        app.config.autoload_paths += [models_path]
      end

      unless app.config.autoload_paths.include?(controllers_path)
        app.config.autoload_paths += [controllers_path]
      end
    end
  end
end