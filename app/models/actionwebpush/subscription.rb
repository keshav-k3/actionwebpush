# frozen_string_literal: true

module ActionWebPush
  class Subscription < ActiveRecord::Base
    self.table_name = "action_web_push_subscriptions"

    belongs_to :user

    validates :endpoint, presence: true
    validates :p256dh_key, presence: true
    validates :auth_key, presence: true
    validates :endpoint, uniqueness: { scope: [:p256dh_key, :auth_key] }

    scope :for_user, ->(user) { where(user: user) }
    scope :active, -> { where("updated_at > ?", 30.days.ago) }
    scope :stale, -> { where("updated_at <= ?", 30.days.ago) }
    scope :created_since, ->(date) { where("created_at >= ?", date) }
    scope :by_user_agent, ->(agent) { where("user_agent ILIKE ?", "%#{agent}%") }

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

    def self.cleanup_stale_subscriptions!
      count = stale.delete_all
      Rails.logger.info "ActionWebPush cleaned up #{count} stale subscriptions" if defined?(Rails)
      count
    end

    def self.bulk_destroy_for_user(user, endpoints = nil)
      scope = for_user(user)
      scope = scope.where(endpoint: endpoints) if endpoints
      scope.delete_all
    end

    def active?
      updated_at > 30.days.ago
    end

    def stale?
      !active?
    end

    def test_delivery!(title: "Test Notification", body: "This is a test push notification")
      notification = build_notification(title: title, body: body)
      notification.deliver_now
      true
    rescue ActionWebPush::Error => e
      false
    end
  end
end