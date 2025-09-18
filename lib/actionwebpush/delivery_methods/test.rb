# frozen_string_literal: true

module ActionWebPush
  module DeliveryMethods
    class Test < Base
      @@deliveries = []

      def self.deliveries
        @@deliveries
      end

      def self.deliveries=(value)
        @@deliveries = value
      end

      def deliver!(notification, connection: nil)
        self.class.deliveries << {
          title: notification.title,
          body: notification.body,
          data: notification.data,
          endpoint: notification.endpoint,
          p256dh_key: notification.p256dh_key,
          auth_key: notification.auth_key,
          options: notification.options,
          delivered_at: Time.now
        }

        logger.info "ActionWebPush::Test delivered: #{notification.title}"
      end

      def self.clear_deliveries!
        deliveries.clear
      end
    end
  end
end