# frozen_string_literal: true

module ActionWebPush
  module DeliveryMethods
    class Base
      include ActionWebPush::Logging

      attr_reader :settings

      def initialize(settings = {})
        @settings = settings
      end

      def deliver!(notification, connection: nil)
        raise NotImplementedError, "Subclasses must implement deliver!"
      end
    end
  end
end