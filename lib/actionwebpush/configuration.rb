# frozen_string_literal: true

module ActionWebPush
  class Configuration
    attr_accessor :vapid_public_key, :vapid_private_key, :vapid_subject
    attr_accessor :pool_size, :queue_size, :delivery_method
    attr_accessor :logger

    def initialize
      @pool_size = 50
      @queue_size = 10000
      @delivery_method = :web_push
      @vapid_subject = "mailto:support@example.com"
      @logger = nil
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
  end
end