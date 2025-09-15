# frozen_string_literal: true

require "test_helper"

class NotificationTest < Minitest::Test
  include ActionWebPush::TestHelper

  def setup
    setup_action_web_push
  end

  def test_initialization
    notification = ActionWebPush::Notification.new(
      title: "Test Title",
      body: "Test body",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      data: { url: "/test" },
      icon: "/icon.png"
    )

    assert_equal "Test Title", notification.title
    assert_equal "Test body", notification.body
    assert_equal "https://example.com", notification.endpoint
    assert_equal "test_key", notification.p256dh_key
    assert_equal "test_auth", notification.auth_key
    assert_equal({ url: "/test" }, notification.data)
    assert_equal "/icon.png", notification.options[:icon]
  end

  def test_deliver_now_with_test_backend
    notification = create_notification

    notification.deliver_now

    assert_equal 1, action_web_push_deliveries.size
    delivery = last_push_delivery
    assert_equal "Test Title", delivery[:title]
    assert_equal "Test body", delivery[:body]
  end

  def test_to_params
    notification = create_notification

    params = notification.to_params

    expected = {
      title: "Test Title",
      body: "Test body",
      data: { url: "/test" },
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      icon: "/icon.png"
    }

    assert_equal expected, params
  end

  private

  def create_notification
    ActionWebPush::Notification.new(
      title: "Test Title",
      body: "Test body",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      data: { url: "/test" },
      icon: "/icon.png"
    )
  end
end