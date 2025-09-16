# frozen_string_literal: true

module ActionWebPush
  class StatusBroadcaster
    class << self
      def broadcast_delivery_status(user_id, notification_id, status, details = {})
        return unless defined?(ActionCable)

        ActionCable.server.broadcast(
          "action_web_push_status_#{user_id}",
          {
            type: "delivery_status",
            notification_id: notification_id,
            status: status,
            timestamp: Time.current.iso8601,
            details: details
          }
        )
      end

      def broadcast_delivery_attempt(user_id, notification_id, subscription_count)
        broadcast_delivery_status(
          user_id,
          notification_id,
          "attempting",
          { subscription_count: subscription_count }
        )
      end

      def broadcast_delivery_success(user_id, notification_id, delivered_count)
        broadcast_delivery_status(
          user_id,
          notification_id,
          "delivered",
          { delivered_count: delivered_count }
        )
      end

      def broadcast_delivery_failure(user_id, notification_id, error_message, failed_count = 1)
        broadcast_delivery_status(
          user_id,
          notification_id,
          "failed",
          { error: error_message, failed_count: failed_count }
        )
      end

      def broadcast_subscription_expired(user_id, subscription_id)
        return unless defined?(ActionCable)

        ActionCable.server.broadcast(
          "action_web_push_status_#{user_id}",
          {
            type: "subscription_expired",
            subscription_id: subscription_id,
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end