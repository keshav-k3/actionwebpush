# frozen_string_literal: true

module ActionWebPush
  class SentryIntegration
    class << self
      def configure
        return unless defined?(Sentry)

        Sentry.configure_scope do |scope|
          scope.set_tag("component", "action_web_push")
        end
      end

      def capture_delivery_error(notification, error, context = {})
        return unless defined?(Sentry)

        Sentry.with_scope do |scope|
          scope.set_tag("action_web_push_event", "delivery_error")
          scope.set_context("notification", notification_context(notification))
          scope.set_context("delivery_context", context)

          if error.is_a?(ActionWebPush::ExpiredSubscriptionError)
            scope.set_level(:info)
            scope.set_tag("error_type", "expired_subscription")
          elsif error.is_a?(ActionWebPush::RateLimitExceeded)
            scope.set_level(:warning)
            scope.set_tag("error_type", "rate_limit_exceeded")
          else
            scope.set_level(:error)
            scope.set_tag("error_type", "delivery_failure")
          end

          Sentry.capture_exception(error)
        end
      end

      def capture_performance_metrics(metrics)
        return unless defined?(Sentry)

        Sentry.with_scope do |scope|
          scope.set_tag("action_web_push_event", "performance_metrics")
          scope.set_context("metrics", metrics)

          if metrics[:success_rate] < 95.0
            Sentry.capture_message(
              "ActionWebPush success rate below threshold: #{metrics[:success_rate]}%",
              level: :warning
            )
          end
        end
      end

      def capture_subscription_event(event_type, subscription, details = {})
        return unless defined?(Sentry)

        Sentry.with_scope do |scope|
          scope.set_tag("action_web_push_event", event_type.to_s)
          scope.set_context("subscription", subscription_context(subscription))
          scope.set_context("event_details", details)

          case event_type
          when :expired
            scope.set_level(:info)
            Sentry.capture_message("Push subscription expired", level: :info)
          when :created
            scope.set_level(:info)
            Sentry.capture_message("Push subscription created", level: :info)
          when :bulk_cleanup
            scope.set_level(:info)
            Sentry.capture_message("Bulk subscription cleanup performed", level: :info)
          end
        end
      end

      private

      def notification_context(notification)
        {
          title: notification.title&.truncate(100),
          endpoint_domain: extract_domain(notification.endpoint),
          has_data: notification.data.present?,
          options_keys: notification.options.keys
        }
      end

      def subscription_context(subscription)
        {
          id: subscription.id,
          endpoint_domain: extract_domain(subscription.endpoint),
          user_agent: subscription.user_agent&.truncate(100),
          created_at: subscription.created_at,
          updated_at: subscription.updated_at,
          active: subscription.active?
        }
      end

      def extract_domain(endpoint)
        URI.parse(endpoint).host
      rescue StandardError
        "unknown"
      end
    end
  end
end