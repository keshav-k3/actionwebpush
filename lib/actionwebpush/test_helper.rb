# frozen_string_literal: true

module ActionWebPush
  module TestHelper
    def setup_action_web_push
      ActionWebPush.configure do |config|
        config.delivery_method = :test
        config.vapid_public_key = "test_public_key"
        config.vapid_private_key = "test_private_key"
        config.vapid_subject = "mailto:test@example.com"
      end

      clear_action_web_push_deliveries
    end

    def clear_action_web_push_deliveries
      ActionWebPush::DeliveryMethods::Test.clear_deliveries!
    end

    def action_web_push_deliveries
      ActionWebPush::DeliveryMethods::Test.deliveries
    end

    def assert_no_push_deliveries
      assert_equal 0, action_web_push_deliveries.size, "Expected no push notifications, but #{action_web_push_deliveries.size} were sent"
    end

    def assert_push_delivered_to(subscription, options = {})
      delivery = action_web_push_deliveries.find do |d|
        d[:endpoint] == subscription.endpoint &&
          d[:p256dh_key] == subscription.p256dh_key &&
          d[:auth_key] == subscription.auth_key
      end

      assert delivery, "Expected push notification to be delivered to subscription #{subscription.id}, but none was found"

      if options[:title]
        assert_equal options[:title], delivery[:title], "Expected title '#{options[:title]}' but got '#{delivery[:title]}'"
      end

      if options[:body]
        assert_equal options[:body], delivery[:body], "Expected body '#{options[:body]}' but got '#{delivery[:body]}'"
      end

      delivery
    end

    def assert_push_deliveries(count)
      assert_equal count, action_web_push_deliveries.size, "Expected #{count} push notifications, but #{action_web_push_deliveries.size} were sent"
    end

    def last_push_delivery
      action_web_push_deliveries.last
    end
  end
end

# Include in Minitest
if defined?(Minitest::Test)
  Minitest::Test.include ActionWebPush::TestHelper
end

# Include in RSpec
if defined?(RSpec)
  RSpec.configure do |config|
    config.include ActionWebPush::TestHelper
  end
end