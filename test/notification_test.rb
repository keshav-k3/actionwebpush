# frozen_string_literal: true

require "test_helper"

class NotificationTest < Minitest::Test
  def setup
    @valid_params = {
      title: "Test Notification",
      body: "This is a test message",
      endpoint: "https://fcm.googleapis.com/fcm/send/test-endpoint",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key"
    }
  end

  def test_notification_creation
    notification = ActionWebPush::Notification.new(**@valid_params)

    assert_equal "Test Notification", notification.title
    assert_equal "This is a test message", notification.body
    assert_equal "https://fcm.googleapis.com/fcm/send/test-endpoint", notification.endpoint
    assert_equal "test_p256dh_key", notification.p256dh_key
    assert_equal "test_auth_key", notification.auth_key
  end

  def test_notification_with_data
    data = { url: "/messages/123", action: "view" }
    notification = ActionWebPush::Notification.new(data: data, **@valid_params)

    assert_equal data, notification.data
  end

  def test_notification_with_options
    options = { icon: "/icon.png", badge: "/badge.png", image: "/image.png" }
    notification = ActionWebPush::Notification.new(**@valid_params, **options)

    assert_equal "/icon.png", notification.options[:icon]
    assert_equal "/badge.png", notification.options[:badge]
    assert_equal "/image.png", notification.options[:image]
  end

  def test_notification_with_actions
    actions = [
      { action: "view", title: "View", icon: "/view.png" },
      { action: "dismiss", title: "Dismiss" }
    ]
    notification = ActionWebPush::Notification.new(actions: actions, **@valid_params)

    assert_equal actions, notification.options[:actions]
  end

  def test_notification_urgency
    notification = ActionWebPush::Notification.new(urgency: "high", **@valid_params)
    assert_equal "high", notification.options[:urgency]

    notification = ActionWebPush::Notification.new(urgency: "normal", **@valid_params)
    assert_equal "normal", notification.options[:urgency]
  end

  def test_notification_ttl
    notification = ActionWebPush::Notification.new(ttl: 3600, **@valid_params)
    assert_equal 3600, notification.options[:ttl]
  end

  def test_notification_silent
    notification = ActionWebPush::Notification.new(silent: true, **@valid_params)
    assert notification.options[:silent]
  end

  def test_notification_require_interaction
    notification = ActionWebPush::Notification.new(require_interaction: true, **@valid_params)
    assert notification.options[:require_interaction]
  end

  def test_notification_tag
    notification = ActionWebPush::Notification.new(tag: "message-123", **@valid_params)
    assert_equal "message-123", notification.options[:tag]
  end

  def test_notification_timestamp
    timestamp = Time.now.to_i * 1000
    notification = ActionWebPush::Notification.new(timestamp: timestamp, **@valid_params)
    assert_equal timestamp, notification.options[:timestamp]
  end

  def test_notification_renotify
    notification = ActionWebPush::Notification.new(renotify: true, **@valid_params)
    assert notification.options[:renotify]
  end

  def test_to_json
    notification = ActionWebPush::Notification.new(**@valid_params)
    json_data = JSON.parse(notification.to_json)

    assert_equal "Test Notification", json_data["title"]
    assert_equal "This is a test message", json_data["body"]
  end

  def test_to_json_with_data_and_options
    data = { url: "/test", id: 123 }
    options = { icon: "/icon.png", tag: "test" }
    notification = ActionWebPush::Notification.new(data: data, **options, **@valid_params)

    json_data = JSON.parse(notification.to_json)

    assert_equal data, json_data["data"]
    assert_equal "/icon.png", json_data["icon"]
    assert_equal "test", json_data["tag"]
  end

  def test_subscription_info
    notification = ActionWebPush::Notification.new(**@valid_params)

    assert_equal @valid_params[:endpoint], notification.endpoint
    assert_equal @valid_params[:p256dh_key], notification.p256dh_key
    assert_equal @valid_params[:auth_key], notification.auth_key
  end

  def test_validation_endpoint_required
    params = @valid_params.dup
    params.delete(:endpoint)

    assert_raises(ArgumentError) do
      ActionWebPush::Notification.new(**params)
    end
  end

  def test_validation_keys_required
    params = @valid_params.dup
    params.delete(:p256dh_key)

    assert_raises(ArgumentError) do
      ActionWebPush::Notification.new(**params)
    end

    params = @valid_params.dup
    params.delete(:auth_key)

    assert_raises(ArgumentError) do
      ActionWebPush::Notification.new(**params)
    end
  end
end