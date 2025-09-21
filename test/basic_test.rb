# frozen_string_literal: true

require_relative "test_helper_clean"

class BasicTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ActionWebPush::VERSION
  end

  def test_configuration_can_be_set
    ActionWebPush.configure do |config|
      config.vapid_subject = "mailto:test@example.com"
      config.pool_size = 25
    end

    assert_equal "mailto:test@example.com", ActionWebPush.config.vapid_subject
    assert_equal 25, ActionWebPush.config.pool_size
  end

  def test_notification_creation
    notification = ActionWebPush::Notification.new(
      title: "Test",
      body: "Test message",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_equal "Test", notification.title
    assert_equal "Test message", notification.body
  end

  def test_notification_with_data_and_options
    notification = ActionWebPush::Notification.new(
      title: "Test",
      body: "Test message",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      data: { url: "/test" },
      icon: "/icon.png",
      tag: "test-tag"
    )

    assert_equal({ url: "/test" }, notification.data)
    assert_equal "/icon.png", notification.options[:icon]
    assert_equal "test-tag", notification.options[:tag]
  end

  def test_delivery_methods_available
    assert_respond_to ActionWebPush::DeliveryMethods, :for

    # Test delivery method should be available
    test_method = ActionWebPush::DeliveryMethods.for(:test)
    assert_kind_of ActionWebPush::DeliveryMethods::Test, test_method

    # Web push delivery method should be available
    web_push_method = ActionWebPush::DeliveryMethods.for(:web_push)
    assert_kind_of ActionWebPush::DeliveryMethods::WebPush, web_push_method
  end

  def test_rate_limiter_initialization
    rate_limiter = ActionWebPush::RateLimiter.new

    assert_instance_of ActionWebPush::RateLimiter, rate_limiter
    assert_respond_to rate_limiter, :check_rate_limit!
    assert_respond_to rate_limiter, :within_rate_limit?
    assert rate_limiter.limits.key?(:endpoint)
    assert rate_limiter.limits.key?(:user)
    assert_equal 100, rate_limiter.limits[:endpoint][:max_requests]
    assert_equal 3600, rate_limiter.limits[:endpoint][:window]
  end
end