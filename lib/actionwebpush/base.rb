# frozen_string_literal: true

module ActionWebPush
  class Base
    class_attribute :default_params
    self.default_params = {}

    attr_reader :params

    def initialize(**params)
      @params = self.class.default_params.merge(params)
    end

    def self.push(subscriptions, **notification_params)
      new(**notification_params).push(subscriptions)
    end

    def push(subscriptions)
      notifications = build_notifications(subscriptions)
      deliver_notifications(notifications)
    end

    def deliver_now(subscriptions)
      push(subscriptions)
    end

    def deliver_later(subscriptions)
      # This will be implemented with ActiveJob integration
      push(subscriptions)
    end

    private

    def build_notifications(subscriptions)
      subscriptions = Array(subscriptions)
      subscriptions.map do |subscription|
        subscription.build_notification(**params)
      end
    end

    def deliver_notifications(notifications)
      if defined?(Rails) && Rails.configuration.x.action_web_push_pool
        Rails.configuration.x.action_web_push_pool.queue(notifications)
      else
        # Fallback to direct delivery
        notifications.each(&:deliver_now)
      end
    end

    def self.default(**params)
      self.default_params = self.default_params.merge(params)
    end
  end
end