# frozen_string_literal: true

require "web-push"

module ActionWebPush
  module DeliveryMethods
    class WebPush < Base
      def deliver!(notification, connection: nil)
        ActionWebPush::Instrumentation.instrument("notification_delivery",
          endpoint: notification.endpoint,
          title: notification.title,
          urgency: notification.options[:urgency] || "high"
        ) do |payload|
          response = ::WebPush.payload_send(
            message: encoded_message(notification),
            endpoint: notification.endpoint,
            p256dh: notification.p256dh_key,
            auth: notification.auth_key,
            vapid: vapid_identification,
            connection: connection,
            urgency: notification.options[:urgency] || "high"
          )

          payload[:success] = response.success?
          payload[:response_code] = response.code if response.respond_to?(:code)

          response.success?
        end
      rescue ::WebPush::ExpiredSubscription => e
        context = {
          endpoint: notification.endpoint,
          subscription_id: notification.respond_to?(:subscription_id) ? notification.subscription_id : nil
        }
        raise ActionWebPush::ErrorHandler.handle_expired_subscription_error(
          ActionWebPush::ExpiredSubscriptionError.new(e.message), context
        )
      rescue StandardError => e
        context = {
          endpoint: notification.endpoint,
          title: notification.title,
          retry_count: 0
        }
        raise ActionWebPush::ErrorHandler.handle_delivery_failure(
          ActionWebPush::DeliveryError.new("Failed to deliver push notification: #{e.message}"), context
        )
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