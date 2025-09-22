# frozen_string_literal: true

module ActionWebPush
  class Configuration
    attr_accessor :vapid_public_key, :vapid_private_key, :vapid_subject
    attr_accessor :pool_size, :queue_size, :delivery_method, :connection_pool_size
    attr_accessor :logger, :timeout, :max_retries, :async
    attr_reader :delivery_methods

    def initialize
      @pool_size = 50
      @queue_size = 10000
      @connection_pool_size = 150
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
      vapid_public_key.present? && vapid_private_key.present?
    end

    def delivery_method_class
      delivery_methods[delivery_method] || raise(ConfigurationError, "Unknown delivery method: #{delivery_method}")
    end

    def add_delivery_method(name, klass)
      delivery_methods[name] = klass
    end
  end
end