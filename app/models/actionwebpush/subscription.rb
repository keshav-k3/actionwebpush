# frozen_string_literal: true

module ActionWebPush
  class Subscription < ActiveRecord::Base
    self.table_name = "action_web_push_subscriptions"

    validates :endpoint, presence: true
    validates :p256dh_key, presence: true
    validates :auth_key, presence: true

    scope :for_user, ->(user) { where(user: user) }

    def build_notification(title:, body:, data: {}, **options)
      ActionWebPush::Notification.new(
        title: title,
        body: body,
        data: data,
        endpoint: endpoint,
        p256dh_key: p256dh_key,
        auth_key: auth_key,
        **options
      )
    end

    def self.find_or_create_subscription(user:, endpoint:, p256dh_key:, auth_key:, **attributes)
      subscription = find_by(
        user: user,
        endpoint: endpoint,
        p256dh_key: p256dh_key,
        auth_key: auth_key
      )

      if subscription
        subscription.touch
        subscription
      else
        create!(
          user: user,
          endpoint: endpoint,
          p256dh_key: p256dh_key,
          auth_key: auth_key,
          **attributes
        )
      end
    end
  end
end