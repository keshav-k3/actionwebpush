# frozen_string_literal: true

module ActionWebPush
  class Configuration
    attr_accessor :vapid_public_key, :vapid_private_key, :vapid_subject
    attr_accessor :pool_size, :queue_size, :delivery_method, :connection_pool_size, :batch_size
    attr_accessor :logger, :timeout, :max_retries, :async
    attr_reader :delivery_methods

    def initialize
      @pool_size = 50
      @queue_size = 10000
      @connection_pool_size = 150
      @batch_size = 100
      @delivery_method = :web_push
      @vapid_subject = "mailto:support@example.com"
      @logger = nil
      @timeout = 30
      @max_retries = 3
      @async = false
      @delivery_methods = {
        web_push: ActionWebPush::DeliveryMethods::WebPush,
        test: ActionWebPush::DeliveryMethods::Test
      }
    end

    def vapid_keys
      {
        public_key: vapid_public_key,
        private_key: vapid_private_key
      }
    end

    def valid?
      validate!
      true
    rescue ConfigurationError
      false
    end

    def validate!
      errors = []

      # VAPID keys validation
      errors << "vapid_public_key is required" if vapid_public_key.blank?
      errors << "vapid_private_key is required" if vapid_private_key.blank?

      if vapid_public_key.present? && vapid_public_key.length != 87
        errors << "vapid_public_key must be 87 characters long (Base64 encoded)"
      end

      if vapid_private_key.present? && vapid_private_key.length != 43
        errors << "vapid_private_key must be 43 characters long (Base64 encoded)"
      end

      # Email validation for vapid_subject
      if vapid_subject.present? && !vapid_subject.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\z/i)
        errors << "vapid_subject must be a valid email address (format: mailto:email@domain.com)"
      end

      # Numeric validations with reasonable bounds
      errors << "pool_size must be between 1 and 1000" unless pool_size.is_a?(Integer) && pool_size.between?(1, 1000)
      errors << "queue_size must be between 1 and 100000" unless queue_size.is_a?(Integer) && queue_size.between?(1, 100000)
      errors << "connection_pool_size must be between 1 and 1000" unless connection_pool_size.is_a?(Integer) && connection_pool_size.between?(1, 1000)
      errors << "batch_size must be between 1 and 10000" unless batch_size.is_a?(Integer) && batch_size.between?(1, 10000)
      errors << "timeout must be between 1 and 300 seconds" unless timeout.is_a?(Integer) && timeout.between?(1, 300)
      errors << "max_retries must be between 0 and 10" unless max_retries.is_a?(Integer) && max_retries.between?(0, 10)

      # Delivery method validation
      unless delivery_methods.key?(delivery_method)
        available = delivery_methods.keys.join(", ")
        errors << "delivery_method must be one of: #{available}"
      end

      # Boolean validation
      unless [true, false].include?(async)
        errors << "async must be true or false"
      end

      raise ConfigurationError, "Configuration errors: #{errors.join('; ')}" if errors.any?
    end

    def delivery_method_class
      delivery_methods[delivery_method] || raise(ConfigurationError, "Unknown delivery method: #{delivery_method}")
    end

    def add_delivery_method(name, klass)
      delivery_methods[name] = klass
    end
  end
end