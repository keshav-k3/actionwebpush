# frozen_string_literal: true

module ActionWebPush
  class Base
    @@default_params = {}

    def self.default_params
      @@default_params
    end

    def self.default_params=(value)
      @@default_params = value
    end

    attr_reader :params

    def initialize(**params)
      @params = self.class.default_params.merge(params)
    end

    def self.push(subscriptions, **notification_params)
      new(**notification_params).push(subscriptions)
    end

    def push(subscriptions, **notification_params)
      if notification_params.empty?
        # Called with just subscriptions, use stored params
        notifications = build_notifications(subscriptions, **@params)
      else
        # Called with both subscriptions and notification params
        notifications = build_notifications(subscriptions, **notification_params)
      end

      deliver_notifications(notifications)
      notifications.first # Return first notification for compatibility
    end

    def deliver_now(subscriptions)
      push(subscriptions)
    end

    def deliver_later(subscriptions, wait: nil, wait_until: nil, queue: nil, priority: nil)
      subscriptions = Array(subscriptions)

      subscriptions.each do |subscription|
        job = ActionWebPush::DeliveryJob.set(
          wait: wait,
          wait_until: wait_until,
          queue: queue || :action_web_push,
          priority: priority
        )

        job.perform_later(params, { id: subscription.id })
      end
    end

    private

    def build_notifications(subscriptions, **notification_params)
      subscriptions = subscriptions.is_a?(Array) ? subscriptions : [subscriptions]
      subscriptions.map do |subscription|
        if subscription.respond_to?(:build_notification)
          subscription.build_notification(**notification_params)
        else
          # Handle hash-based subscription data
          ActionWebPush::Notification.new(
            endpoint: subscription.is_a?(Hash) ? subscription[:endpoint] : subscription.endpoint,
            p256dh_key: subscription.is_a?(Hash) ? subscription[:p256dh_key] : subscription.p256dh_key,
            auth_key: subscription.is_a?(Hash) ? subscription[:auth_key] : subscription.auth_key,
            **notification_params
          )
        end
      end
    end

    def deliver_notifications(notifications)
      if defined?(Rails) && Rails.respond_to?(:configuration) && Rails.configuration.respond_to?(:x) && Rails.configuration.x.respond_to?(:action_web_push_pool)
        Rails.configuration.x.action_web_push_pool.queue(notifications)
      else
        # Fallback to direct delivery
        delivery_method = ActionWebPush::DeliveryMethods.for(ActionWebPush.config.delivery_method)
        notifications.each { |notification| delivery_method.deliver!(notification) }
      end
    end

    def self.default(**params)
      self.default_params = self.default_params.merge(params)
    end
  end
end