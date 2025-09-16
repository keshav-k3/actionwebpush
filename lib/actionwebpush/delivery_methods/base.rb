# frozen_string_literal: true

require "logger"

module ActionWebPush
  module DeliveryMethods
    class Base
      attr_reader :settings

      def initialize(settings = {})
        @settings = settings
      end

      def deliver!(notification, connection: nil)
        raise NotImplementedError, "Subclasses must implement deliver!"
      end

      protected

      def logger
        ActionWebPush.config.logger ||
          (defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : Logger.new(STDOUT))
      end
    end
  end
end