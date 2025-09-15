# frozen_string_literal: true

require "web-push"

module ActionWebPush
  module DeliveryMethods
    class WebPush < Base
      def deliver!(notification, connection: nil)
        ::WebPush.payload_send(
          message: encoded_message(notification),
          endpoint: notification.endpoint,
          p256dh: notification.p256dh_key,
          auth: notification.auth_key,
          vapid: vapid_identification,
          connection: connection,
          urgency: notification.options[:urgency] || "high"
        )
      rescue ::WebPush::ExpiredSubscription => e
        raise ActionWebPush::ExpiredSubscriptionError, e.message
      rescue StandardError => e
        raise ActionWebPush::DeliveryError, "Failed to deliver push notification: #{e.message}"
      end

      private

      def vapid_identification
        config = ActionWebPush.config
        {
          subject: config.vapid_subject,
          public_key: config.vapid_public_key,
          private_key: config.vapid_private_key
        }
      end

      def encoded_message(notification)
        payload = {
          title: notification.title,
          options: {
            body: notification.body,
            icon: notification.options[:icon],
            badge: notification.options[:badge],
            data: notification.data
          }
        }

        JSON.generate(payload)
      end
    end
  end
end