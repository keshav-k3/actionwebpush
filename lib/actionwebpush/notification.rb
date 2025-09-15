# frozen_string_literal: true

require "web-push"

module ActionWebPush
  class Notification
    attr_reader :title, :body, :data, :endpoint, :p256dh_key, :auth_key, :options

    def initialize(title:, body:, endpoint:, p256dh_key:, auth_key:, data: {}, **options)
      @title = title
      @body = body
      @data = data
      @endpoint = endpoint
      @p256dh_key = p256dh_key
      @auth_key = auth_key
      @options = options
    end

    def deliver(connection: nil)
      WebPush.payload_send(
        message: encoded_message,
        endpoint: endpoint,
        p256dh: p256dh_key,
        auth: auth_key,
        vapid: vapid_identification,
        connection: connection,
        urgency: options[:urgency] || "high"
      )
    end

    def deliver_now(connection: nil)
      deliver(connection: connection)
    end

    def deliver_later
      # This will be implemented with ActiveJob integration
      deliver_now
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

    def encoded_message
      payload = {
        title: title,
        options: {
          body: body,
          icon: options[:icon],
          badge: options[:badge],
          data: data
        }
      }

      JSON.generate(payload)
    end
  end
end