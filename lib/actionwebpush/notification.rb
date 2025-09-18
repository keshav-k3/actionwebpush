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
      delivery_method = ActionWebPush.config.delivery_method_class.new
      delivery_method.deliver!(self, connection: connection)
    end

    def deliver_now(connection: nil)
      deliver(connection: connection)
    end

    def deliver_later(wait: nil, wait_until: nil, queue: nil, priority: nil)
      job = ActionWebPush::DeliveryJob.set(
        wait: wait,
        wait_until: wait_until,
        queue: queue || :action_web_push,
        priority: priority
      )

      job.perform_later(to_params)
    end

    def to_params
      {
        title: title,
        body: body,
        data: data,
        endpoint: endpoint,
        p256dh_key: p256dh_key,
        auth_key: auth_key
      }.merge(options)
    end

    def to_json(*args)
      {
        title: title,
        body: body,
        data: data
      }.merge(options).to_json(*args)
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