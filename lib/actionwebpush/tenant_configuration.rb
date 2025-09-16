# frozen_string_literal: true

module ActionWebPush
  class TenantConfiguration
    attr_accessor :tenant_id, :vapid_public_key, :vapid_private_key, :vapid_subject
    attr_accessor :pool_size, :queue_size, :delivery_method, :rate_limits
    attr_accessor :webhook_url, :custom_settings

    def initialize(tenant_id, **options)
      @tenant_id = tenant_id
      @vapid_public_key = options[:vapid_public_key]
      @vapid_private_key = options[:vapid_private_key]
      @vapid_subject = options[:vapid_subject] || "mailto:support@example.com"
      @pool_size = options[:pool_size] || 50
      @queue_size = options[:queue_size] || 10000
      @delivery_method = options[:delivery_method] || :web_push
      @rate_limits = options[:rate_limits] || {}
      @webhook_url = options[:webhook_url]
      @custom_settings = options[:custom_settings] || {}
    end

    def valid?
      vapid_public_key.present? && vapid_private_key.present?
    end

    def vapid_keys
      {
        public_key: vapid_public_key,
        private_key: vapid_private_key,
        subject: vapid_subject
      }
    end

    def to_h
      {
        tenant_id: tenant_id,
        vapid_public_key: vapid_public_key,
        vapid_private_key: vapid_private_key,
        vapid_subject: vapid_subject,
        pool_size: pool_size,
        queue_size: queue_size,
        delivery_method: delivery_method,
        rate_limits: rate_limits,
        webhook_url: webhook_url,
        custom_settings: custom_settings
      }
    end
  end

  class TenantManager
    class << self
      attr_accessor :configurations

      def configure_tenant(tenant_id, **options)
        self.configurations ||= {}
        configurations[tenant_id] = TenantConfiguration.new(tenant_id, **options)
      end

      def configuration_for(tenant_id)
        configurations&.[](tenant_id) || raise(ConfigurationError, "No configuration found for tenant: #{tenant_id}")
      end

      def tenant_exists?(tenant_id)
        configurations&.key?(tenant_id) || false
      end

      def all_tenants
        configurations&.keys || []
      end

      def reset!
        self.configurations = {}
      end
    end
  end

  module TenantAware
    extend ActiveSupport::Concern

    included do
      class_attribute :tenant_column, default: :tenant_id

      scope :for_tenant, ->(tenant_id) { where(tenant_column => tenant_id) }

      before_validation :set_tenant_id, if: :should_set_tenant_id?
    end

    class_methods do
      def tenant_aware(column: :tenant_id)
        self.tenant_column = column
      end
    end

    private

    def should_set_tenant_id?
      respond_to?(tenant_column) &&
        public_send(tenant_column).blank? &&
        ActionWebPush.current_tenant_id.present?
    end

    def set_tenant_id
      public_send("#{tenant_column}=", ActionWebPush.current_tenant_id)
    end
  end
end