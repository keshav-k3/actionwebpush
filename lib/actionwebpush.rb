# frozen_string_literal: true

require_relative "actionwebpush/version"

module ActionWebPush
  class Error < StandardError; end
  class DeliveryError < Error; end
  class ExpiredSubscriptionError < Error; end
  class ConfigurationError < Error; end
  class RateLimitExceeded < Error; end

  autoload :Configuration, "actionwebpush/configuration"
  autoload :Notification, "actionwebpush/notification"
  autoload :Pool, "actionwebpush/pool"
  autoload :Base, "actionwebpush/base"
  autoload :DeliveryJob, "actionwebpush/delivery_job"
  autoload :BatchDelivery, "actionwebpush/batch_delivery"
  autoload :Metrics, "actionwebpush/metrics"
  autoload :TestHelper, "actionwebpush/test_helper"
  autoload :StatusChannel, "actionwebpush/status_channel"
  autoload :StatusBroadcaster, "actionwebpush/status_broadcaster"
  autoload :RateLimiter, "actionwebpush/rate_limiter"
  autoload :TenantConfiguration, "actionwebpush/tenant_configuration"
  autoload :TenantManager, "actionwebpush/tenant_configuration"
  autoload :SentryIntegration, "actionwebpush/sentry_integration"
  autoload :Analytics, "actionwebpush/analytics"

  module DeliveryMethods
    autoload :Base, "actionwebpush/delivery_methods/base"
    autoload :WebPush, "actionwebpush/delivery_methods/web_push"
    autoload :Test, "actionwebpush/delivery_methods/test"
  end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def config
      self.configuration ||= Configuration.new
    end
  end
end

if defined?(Rails)
  require "actionwebpush/railtie"
  require "actionwebpush/engine"
end
