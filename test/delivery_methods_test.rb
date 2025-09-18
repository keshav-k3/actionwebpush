# frozen_string_literal: true

require_relative "test_helper_clean"

class DeliveryMethodsTest < Minitest::Test
  def setup
    # Clear deliveries before each test
    ActionWebPush::DeliveryMethods::Test.clear_deliveries!

    @notification = ActionWebPush::Notification.new(
      title: "Test Notification",
      body: "Test message",
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key",
      data: { url: "/test" }
    )

    ActionWebPush.configure do |config|
      config.vapid_public_key = "test_public_key"
      config.vapid_private_key = "test_private_key"
      config.vapid_subject = "mailto:test@example.com"
    end
  end

  def test_base_delivery_method
    base = ActionWebPush::DeliveryMethods::Base.new

    assert_raises(NotImplementedError) do
      base.deliver!(@notification)
    end
  end

  def test_test_delivery_method
    test_method = ActionWebPush::DeliveryMethods::Test.new

    # Should not raise error
    result = test_method.deliver!(@notification)
    assert result

    # Should store delivery in test deliveries
    deliveries = ActionWebPush::DeliveryMethods::Test.deliveries
    assert_equal 1, deliveries.length

    delivery = deliveries.first
    assert_equal "Test Notification", delivery[:title]
    assert_equal "Test message", delivery[:body]
    assert_equal({ url: "/test" }, delivery[:data])
  end

  def test_test_delivery_method_clear_deliveries
    test_method = ActionWebPush::DeliveryMethods::Test.new

    # Deliver some notifications
    3.times { test_method.deliver!(@notification) }

    assert_equal 3, ActionWebPush::DeliveryMethods::Test.deliveries.length

    # Clear deliveries
    ActionWebPush::DeliveryMethods::Test.clear_deliveries!

    assert_equal 0, ActionWebPush::DeliveryMethods::Test.deliveries.length
  end

  def test_web_push_delivery_method
    skip "WebPush not available" unless defined?(::WebPush)

    web_push_method = ActionWebPush::DeliveryMethods::WebPush.new

    # Mock WebPush response
    mock_response = Minitest::Mock.new
    mock_response.expect :success?, true

    ::WebPush.stub :payload_send, -> (*args) { mock_response } do
      result = web_push_method.deliver!(@notification)
      assert result
    end

    mock_response.verify
  end

  def test_web_push_delivery_method_with_error
    skip "WebPush not available" unless defined?(::WebPush)

    web_push_method = ActionWebPush::DeliveryMethods::WebPush.new

    # Mock WebPush error
    ::WebPush.stub :payload_send, -> (*args) { raise ::WebPush::ResponseError.new("Test error") } do
      assert_raises(ActionWebPush::DeliveryError) do
        web_push_method.deliver!(@notification)
      end
    end
  end

  def test_web_push_expired_subscription_handling
    skip "WebPush not available" unless defined?(::WebPush)

    web_push_method = ActionWebPush::DeliveryMethods::WebPush.new

    # Mock expired subscription error - simplified for testing
    ::WebPush.stub :payload_send, -> (*args) { raise StandardError.new("410 Gone") } do
      assert_raises(ActionWebPush::DeliveryError) do
        web_push_method.deliver!(@notification)
      end
    end
  end

  def test_delivery_method_selection
    # Test delivery method
    ActionWebPush.configure { |config| config.delivery_method = :test }
    method = ActionWebPush::DeliveryMethods.for(:test)
    assert_kind_of ActionWebPush::DeliveryMethods::Test, method

    # Web push delivery method
    ActionWebPush.configure { |config| config.delivery_method = :web_push }
    method = ActionWebPush::DeliveryMethods.for(:web_push)
    assert_kind_of ActionWebPush::DeliveryMethods::WebPush, method
  end

  def test_custom_delivery_method
    # Create custom delivery method
    custom_class = Class.new(ActionWebPush::DeliveryMethods::Base) do
      def deliver!(notification, connection: nil)
        @delivered_notification = notification
        true
      end

      attr_reader :delivered_notification
    end

    # Register custom method
    ActionWebPush::DeliveryMethods.register(:custom, custom_class)

    method = ActionWebPush::DeliveryMethods.for(:custom)
    assert_kind_of custom_class, method

    result = method.deliver!(@notification)
    assert result
    assert_equal @notification, method.delivered_notification
  end
end