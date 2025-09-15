# frozen_string_literal: true

module ActionWebPush
  class DeliveryJob < ActiveJob::Base
    queue_as :action_web_push

    # Retry on transient failures
    retry_on ActionWebPush::DeliveryError, wait: :polynomially_longer, attempts: 5
    retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 3
    retry_on Errno::ECONNREFUSED, wait: :exponentially_longer, attempts: 3

    # Don't retry on permanent failures
    discard_on ActionWebPush::ExpiredSubscriptionError
    discard_on ActiveRecord::RecordNotFound

    def perform(notification_params, subscription_params = nil)
      if subscription_params
        # Single subscription with notification data
        subscription = ActionWebPush::Subscription.find(subscription_params[:id])
        notification = subscription.build_notification(**notification_params)
        deliver_with_error_handling(notification, subscription)
      else
        # Direct notification delivery
        notification = ActionWebPush::Notification.new(**notification_params)
        deliver_with_error_handling(notification)
      end
    end

    private

    def deliver_with_error_handling(notification, subscription = nil)
      notification.deliver_now

      logger.info "ActionWebPush delivered: #{notification.title} to #{notification.endpoint[0..50]}..."
    rescue ActionWebPush::ExpiredSubscriptionError => e
      # Handle expired subscription
      if subscription
        subscription.destroy
        logger.info "ActionWebPush destroyed expired subscription: #{subscription.id}"
      end
      raise # Re-raise to trigger discard_on
    rescue ActionWebPush::DeliveryError => e
      # Log delivery error and re-raise for retry
      logger.warn "ActionWebPush delivery failed (will retry): #{e.message}"
      raise
    rescue StandardError => e
      # Catch-all for unexpected errors
      logger.error "ActionWebPush unexpected error: #{e.class} #{e.message}"
      raise ActionWebPush::DeliveryError, "Unexpected delivery failure: #{e.message}"
    end
  end
end