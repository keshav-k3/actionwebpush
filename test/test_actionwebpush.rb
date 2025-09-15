# frozen_string_literal: true

require "test_helper"

class TestActionWebPush < Minitest::Test
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
end
