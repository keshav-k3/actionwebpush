# frozen_string_literal: true

module ActionWebPush
  class Subscription < ActiveRecord::Base
    include ActionWebPush::Logging
    include ActionWebPush::Authorization

    self.table_name = "action_web_push_subscriptions"

    belongs_to :user

    validates :endpoint, presence: true
    validates :p256dh_key, presence: true
    validates :auth_key, presence: true
    validates :endpoint, uniqueness: { scope: [:p256dh_key, :auth_key] }

    # Lifecycle callbacks
    before_create :log_subscription_creation
    before_destroy :log_subscription_destruction
    after_touch :log_subscription_activity

    scope :for_user, ->(user) { where(user: user) }
    scope :active, -> { where("updated_at > ?", 30.days.ago) }
    scope :stale, -> { where("updated_at <= ?", 30.days.ago) }
    scope :created_since, ->(date) { where("created_at >= ?", date) }
    scope :by_user_agent, ->(agent) {
      return none if agent.blank?
      escaped_agent = sanitize_sql_like(agent.to_s)
      where("user_agent ILIKE ?", "%#{escaped_agent}%")
    }

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

    def self.find_or_create_subscription(user:, endpoint:, p256dh_key:, auth_key:, current_user: nil, **attributes)
      # Authorization check
      current_user ||= ActionWebPush::Authorization::Utils.current_user_context
      authorize_subscription_creation!(user: user, current_user: current_user, **attributes)

      subscription = find_by(
        user: user,
        endpoint: endpoint,
        p256dh_key: p256dh_key,
        auth_key: auth_key
      )

      if subscription
        # Check if current user can access this existing subscription
        if current_user && !ActionWebPush::Authorization::Utils.authorization_bypassed?
          authorize_subscription_management!(current_user: current_user, subscription: subscription)
        end
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

    def self.cleanup_stale_subscriptions!(dry_run: false)
      stale_subscriptions = stale
      count = stale_subscriptions.count

      if dry_run
        ActionWebPush.logger.info "ActionWebPush would cleanup #{count} stale subscriptions (dry run)"
        return count
      end

      stale_subscriptions.delete_all
      ActionWebPush.logger.info "ActionWebPush cleaned up #{count} stale subscriptions"
      count
    end

    def self.bulk_destroy_for_user(user, endpoints = nil, current_user: nil)
      # Authorization check
      current_user ||= ActionWebPush::Authorization::Utils.current_user_context
      if current_user && !ActionWebPush::Authorization::Utils.authorization_bypassed?
        unless can_create_subscription_for_user?(current_user, user)
          raise ActionWebPush::Authorization::ForbiddenError,
                "User #{current_user.id} is not authorized to manage subscriptions for user #{user.id}"
        end
      end

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
      touch # Update last activity
      true
    rescue ActionWebPush::Error => e
      logger.warn "Test delivery failed for subscription #{id}: #{e.message}"
      false
    end

    def mark_as_expired!
      logger.info "Marking subscription #{id} as expired"
      destroy
    end

    def refresh_activity!
      touch
      logger.debug "Refreshed activity for subscription #{id}"
    end

    def endpoint_domain
      URI.parse(endpoint).host
    rescue URI::InvalidURIError
      nil
    end

    def days_since_last_activity
      (((Time.respond_to?(:current) ? Time.current : Time.now) - updated_at) / 1.day).round
    end

    def self.stats
      {
        total: count,
        active: active.count,
        stale: stale.count,
        by_domain: group("SUBSTRING(endpoint FROM 'https?://([^/]+)')").count
      }
    end

    private

    def log_subscription_creation
      logger.info "Creating push subscription for user #{user_id} on #{endpoint_domain}"
    end

    def log_subscription_destruction
      logger.info "Destroying push subscription #{id} for user #{user_id}"
    end

    def log_subscription_activity
      logger.debug "Push subscription #{id} activity updated"
    end
  end
end