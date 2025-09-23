# frozen_string_literal: true

module ActionWebPush
  module ErrorHandler
    def self.handle_delivery_error(error, context = {})
      case error
      when ActionWebPush::ExpiredSubscriptionError
        handle_expired_subscription_error(error, context)
      when ActionWebPush::RateLimitExceeded
        handle_rate_limit_error(error, context)
      when ActionWebPush::DeliveryError
        handle_delivery_failure(error, context)
      when ActionWebPush::ConfigurationError
        handle_configuration_error(error, context)
      else
        handle_unexpected_error(error, context)
      end
    end

    def self.handle_expired_subscription_error(error, context)
      ActionWebPush::Instrumentation.publish("subscription_expired",
        error: error.message,
        endpoint: context[:endpoint],
        subscription_id: context[:subscription_id]
      )

      ActionWebPush.logger.info "Subscription expired: #{error.message}"

      # Cleanup subscription if possible
      cleanup_expired_subscription(context[:subscription_id]) if context[:subscription_id]

      error
    end

    def self.handle_rate_limit_error(error, context)
      ActionWebPush::Instrumentation.publish("rate_limit_exceeded",
        error: error.message,
        resource_type: context[:resource_type],
        resource_id: context[:resource_id]
      )

      ActionWebPush.logger.warn "Rate limit exceeded: #{error.message}"
      error
    end

    def self.handle_delivery_failure(error, context)
      ActionWebPush::Instrumentation.publish("notification_delivery_failed",
        error: error.message,
        error_class: error.class.name,
        endpoint: context[:endpoint],
        notification_title: context[:title],
        retry_count: context[:retry_count] || 0
      )

      log_level = context[:retry_count]&.> 2 ? :error : :warn
      ActionWebPush.logger.send(log_level, "Delivery failed: #{error.message}")

      error
    end

    def self.handle_configuration_error(error, context)
      ActionWebPush::Instrumentation.publish("configuration_error",
        error: error.message,
        context: context
      )

      ActionWebPush.logger.error "Configuration error: #{error.message}"
      error
    end

    def self.handle_unexpected_error(error, context)
      ActionWebPush::Instrumentation.publish("unexpected_error",
        error: error.message,
        error_class: error.class.name,
        backtrace: error.backtrace&.first(5),
        context: context
      )

      ActionWebPush.logger.error "Unexpected error in ActionWebPush: #{error.class} #{error.message}"

      # Wrap in ActionWebPush error for consistency
      ActionWebPush::DeliveryError.new("Unexpected error: #{error.message}")
    end

    private

    def self.cleanup_expired_subscription(subscription_id)
      return unless defined?(ActionWebPush::Subscription)

      subscription = ActionWebPush::Subscription.find_by(id: subscription_id)
      subscription&.destroy

      ActionWebPush.logger.debug "Cleaned up expired subscription #{subscription_id}"
    rescue StandardError => e
      ActionWebPush.logger.warn "Failed to cleanup expired subscription #{subscription_id}: #{e.message}"
    end
  end
end