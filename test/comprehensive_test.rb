# frozen_string_literal: true

require_relative "test_helper_clean"

class ComprehensiveTest < Minitest::Test
  def test_web_push_delivery_with_mock
    skip "WebPush gem not available" unless defined?(::WebPush)

    # Configure ActionWebPush
    ActionWebPush.configure do |config|
      config.vapid_public_key = "test_public_key"
      config.vapid_private_key = "test_private_key"
      config.vapid_subject = "mailto:test@example.com"
    end

    notification = ActionWebPush::Notification.new(
      title: "Test Web Push",
      body: "Test message for web push",
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key",
      data: { url: "/test" }
    )

    web_push_method = ActionWebPush::DeliveryMethods.for(:web_push)

    # Mock WebPush.payload_send to avoid actual network call
    mock_response = Minitest::Mock.new
    mock_response.expect :success?, true

    ::WebPush.stub :payload_send, -> (*args) { mock_response } do
      result = web_push_method.deliver!(notification)
      assert result, "Web push delivery should succeed"
    end

    mock_response.verify
  end

  def test_test_delivery_method
    ActionWebPush::DeliveryMethods::Test.clear_deliveries!

    notification = ActionWebPush::Notification.new(
      title: "Test Notification",
      body: "Test message",
      endpoint: "https://test.example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      data: { id: 123 }
    )

    test_method = ActionWebPush::DeliveryMethods.for(:test)
    test_method.deliver!(notification)

    deliveries = ActionWebPush::DeliveryMethods::Test.deliveries
    assert_equal 1, deliveries.length

    delivery = deliveries.first
    assert_equal "Test Notification", delivery[:title]
    assert_equal "Test message", delivery[:body]
    assert_equal({ id: 123 }, delivery[:data])
    assert delivery[:delivered_at]
  end

  def test_pool_creation_and_configuration
    ActionWebPush.configure do |config|
      config.pool_size = 5
      config.timeout = 30
    end

    # Test that Pool can be created with configuration
    pool = ActionWebPush::Pool.new
    assert_kind_of ActionWebPush::Pool, pool
  end

  def test_base_pusher_class
    # Create a test pusher class
    test_pusher_class = Class.new(ActionWebPush::Base) do
      def test_notification(user_id)
        push(
          {
            endpoint: "https://fcm.googleapis.com/fcm/send/#{user_id}",
            p256dh_key: "test_p256dh_#{user_id}",
            auth_key: "test_auth_#{user_id}"
          },
          title: "Test",
          body: "Hello user #{user_id}!",
          data: { user_id: user_id }
        )
      end
    end

    ActionWebPush.configure do |config|
      config.delivery_method = :test
    end

    pusher = test_pusher_class.new
    notification = pusher.test_notification(123)

    assert_kind_of ActionWebPush::Notification, notification
    assert_equal "Test", notification.title
    assert_equal "Hello user 123!", notification.body
  end

  def test_notification_json_serialization
    notification = ActionWebPush::Notification.new(
      title: "JSON Test",
      body: "Testing JSON serialization",
      endpoint: "https://example.com",
      p256dh_key: "key",
      auth_key: "auth",
      data: { custom: "data", number: 42 },
      icon: "/icon.png",
      actions: [
        { action: "view", title: "View" },
        { action: "dismiss", title: "Dismiss" }
      ]
    )

    json_str = notification.to_json
    parsed = JSON.parse(json_str)

    assert_equal "JSON Test", parsed["title"]
    assert_equal "Testing JSON serialization", parsed["body"]
    assert_equal({ "custom" => "data", "number" => 42 }, parsed["data"])
    assert_equal "/icon.png", parsed["icon"]
    assert_equal 2, parsed["actions"].length
  end

  def test_error_classes_defined
    assert defined?(ActionWebPush::Error)
    assert defined?(ActionWebPush::DeliveryError)
    assert defined?(ActionWebPush::ExpiredSubscriptionError)
    assert defined?(ActionWebPush::ConfigurationError)
    assert defined?(ActionWebPush::RateLimitExceeded)

    # Test inheritance
    assert ActionWebPush::DeliveryError < ActionWebPush::Error
    assert ActionWebPush::ExpiredSubscriptionError < ActionWebPush::Error
    assert ActionWebPush::ConfigurationError < ActionWebPush::Error
    assert ActionWebPush::RateLimitExceeded < ActionWebPush::Error
  end

  def test_configuration_defaults
    config = ActionWebPush::Configuration.new

    # Test reasonable defaults
    refute_nil config.delivery_method
    assert config.pool_size > 0
    assert config.timeout > 0
    assert config.max_retries >= 0
  end
end