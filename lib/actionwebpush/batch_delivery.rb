# frozen_string_literal: true

module ActionWebPush
  class BatchDelivery
    include ActionWebPush::Logging
    attr_reader :notifications, :pool

    def initialize(notifications, pool: nil)
      @notifications = Array(notifications)
      @pool = pool || (defined?(Rails) ? Rails.configuration.x.action_web_push_pool : nil)
    end

    def deliver_all
      if pool
        batch_deliver_with_pool
      else
        direct_batch_deliver
      end
    end

    def self.deliver(notifications, **options)
      new(notifications, **options).deliver_all
    end

    private

    def batch_deliver_with_pool
      # Group notifications by endpoint to avoid overwhelming single endpoints
      grouped = notifications.group_by(&:endpoint)

      grouped.each do |endpoint, endpoint_notifications|
        # Stagger delivery to same endpoint to avoid rate limiting
        endpoint_notifications.each_with_index do |notification, index|
          pool.delivery_pool.post do
            sleep(index * 0.01) if index > 0 # Small delay between same endpoint
            deliver_single(notification)
          end
        end
      end
    end

    def direct_batch_deliver
      notifications.each { |notification| deliver_single(notification) }
    end

    def deliver_single(notification)
      notification.deliver_now
    rescue ActionWebPush::ExpiredSubscriptionError => e
      # Handle expired subscription cleanup if we can identify the subscription
      handle_expired_subscription(notification)
    rescue StandardError => e
      logger.error "ActionWebPush batch delivery failed: #{e.class} #{e.message}"
    end

    def handle_expired_subscription(notification)
      # Try to find and clean up the expired subscription
      subscription = ActionWebPush::Subscription.find_by(endpoint: notification.endpoint)
      subscription&.destroy
    rescue StandardError => e
      logger.warn "Failed to cleanup expired subscription: #{e.message}"
    end

  end
end