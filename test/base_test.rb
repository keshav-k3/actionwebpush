# frozen_string_literal: true

require "test_helper"

class BaseTest < Minitest::Test
  def setup
    ActionWebPush.configure do |config|
      config.vapid_public_key = "test_public_key"
      config.vapid_private_key = "test_private_key"
      config.vapid_subject = "mailto:test@example.com"
      config.delivery_method = :test
    end

    @test_pusher = Class.new(ActionWebPush::Base) do
      def welcome_notification(user)
        push(
          [create_mock_subscription(user)],
          title: "Welcome!",
          body: "Welcome to our app, #{user[:name]}!",
          data: { url: "/dashboard" }
        )
      end

      def bulk_notification(users)
        subscriptions = users.map { |user| create_mock_subscription(user) }
        push(
          subscriptions,
          title: "Announcement",
          body: "Important announcement for all users",
          data: { type: "announcement" }
        )
      end

      private

      def create_mock_subscription(user)
        {
          endpoint: "https://fcm.googleapis.com/fcm/send/#{user[:id]}",
          p256dh_key: "mock_p256dh_#{user[:id]}",
          auth_key: "mock_auth_#{user[:id]}"
        }
      end
    end
  end

  def test_class_inheritance
    pusher = @test_pusher.new
    assert_kind_of ActionWebPush::Base, pusher
  end

  def test_deliver_now
    user = { id: 1, name: "John Doe" }
    pusher = @test_pusher.new

    notification = pusher.welcome_notification(user)
    result = notification.deliver_now

    assert_kind_of ActionWebPush::Notification, notification
    # In test mode, should return success
    assert result
  end

  def test_deliver_later
    user = { id: 2, name: "Jane Smith" }
    pusher = @test_pusher.new

    notification = pusher.welcome_notification(user)

    # Mock ActiveJob
    job_mock = Minitest::Mock.new
    job_mock.expect :perform_later, true, [notification]

    ActionWebPush::DeliveryJob.stub :new, job_mock do
      result = notification.deliver_later
      assert result
    end

    job_mock.verify
  end

  def test_bulk_delivery
    users = [
      { id: 1, name: "User 1" },
      { id: 2, name: "User 2" },
      { id: 3, name: "User 3" }
    ]
    pusher = @test_pusher.new

    notification = pusher.bulk_notification(users)

    # Should create notifications for multiple subscriptions
    assert_kind_of ActionWebPush::Notification, notification
    # In test mode, verify the notification content
    assert_equal "Announcement", notification.title
    assert_equal "Important announcement for all users", notification.body
    assert_equal({ type: "announcement" }, notification.data)
  end

  def test_push_with_single_subscription
    pusher = @test_pusher.new
    subscription = {
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_p256dh",
      auth_key: "test_auth"
    }

    notification = pusher.send(:push, subscription,
                               title: "Test",
                               body: "Test message")

    assert_equal "Test", notification.title
    assert_equal "Test message", notification.body
    assert_equal subscription[:endpoint], notification.endpoint
  end

  def test_push_with_multiple_subscriptions
    pusher = @test_pusher.new
    subscriptions = [
      {
        endpoint: "https://fcm.googleapis.com/fcm/send/1",
        p256dh_key: "p256dh_1",
        auth_key: "auth_1"
      },
      {
        endpoint: "https://fcm.googleapis.com/fcm/send/2",
        p256dh_key: "p256dh_2",
        auth_key: "auth_2"
      }
    ]

    # For multiple subscriptions, should use batch delivery
    batch_mock = Minitest::Mock.new
    batch_mock.expect :add_notification, nil, [ActionWebPush::Notification]
    batch_mock.expect :add_notification, nil, [ActionWebPush::Notification]
    batch_mock.expect :deliver, true

    ActionWebPush::BatchDelivery.stub :new, batch_mock do
      result = pusher.send(:push, subscriptions,
                          title: "Batch Test",
                          body: "Batch message")
      assert result
    end

    batch_mock.verify
  end

  def test_configuration_access
    pusher = @test_pusher.new
    config = pusher.send(:config)

    assert_equal "test_public_key", config.vapid_public_key
    assert_equal "test_private_key", config.vapid_private_key
    assert_equal "mailto:test@example.com", config.vapid_subject
  end

  def test_error_handling_with_invalid_subscription
    pusher = @test_pusher.new
    invalid_subscription = {
      endpoint: "",
      p256dh_key: "",
      auth_key: ""
    }

    assert_raises(ActionWebPush::Error) do
      pusher.send(:push, invalid_subscription,
                 title: "Test",
                 body: "Test")
    end
  end

  def test_custom_delivery_method
    ActionWebPush.configure do |config|
      config.delivery_method = :web_push
    end

    pusher = @test_pusher.new
    user = { id: 1, name: "Test User" }

    # Should work with web_push delivery method
    notification = pusher.welcome_notification(user)
    assert_kind_of ActionWebPush::Notification, notification
  end

  def test_notification_options_passthrough
    pusher = @test_pusher.new
    subscription = {
      endpoint: "https://test.endpoint.com",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    }

    notification = pusher.send(:push, subscription,
                               title: "Test",
                               body: "Message",
                               icon: "/icon.png",
                               tag: "test-tag",
                               urgency: "high",
                               ttl: 3600)

    assert_equal "/icon.png", notification.options[:icon]
    assert_equal "test-tag", notification.options[:tag]
    assert_equal "high", notification.options[:urgency]
    assert_equal 3600, notification.options[:ttl]
  end
end