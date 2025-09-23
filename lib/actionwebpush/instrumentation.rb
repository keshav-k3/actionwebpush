# frozen_string_literal: true

module ActionWebPush
  module Instrumentation
    def self.instrument(event_name, payload = {})
      if defined?(ActiveSupport::Notifications)
        ActiveSupport::Notifications.instrument("action_web_push.#{event_name}", payload) do |notification_payload|
          yield notification_payload if block_given?
        end
      else
        yield payload if block_given?
      end
    end

    def self.publish(event_name, payload = {})
      if defined?(ActiveSupport::Notifications)
        ActiveSupport::Notifications.publish("action_web_push.#{event_name}", payload)
      end
    end

    # Available events:
    # action_web_push.notification_delivery
    # action_web_push.notification_delivery_failed
    # action_web_push.pool_overflow
    # action_web_push.rate_limit_exceeded
    # action_web_push.batch_delivery
    # action_web_push.subscription_expired
    # action_web_push.subscription_created
    # action_web_push.subscription_destroyed
  end
end