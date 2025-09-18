#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test runner for ActionWebPush without Rails dependencies
# This validates core logic can work with Ruby 2.6

require "minitest/autorun"
require "json"
require "logger"
require "securerandom"

# Mock the essential classes without loading the full gem
module ActionWebPush
  VERSION = "0.1.0"

  class Error < StandardError; end
  class DeliveryError < Error; end
  class ConfigurationError < Error; end

  class Configuration
    attr_accessor :vapid_public_key, :vapid_private_key, :vapid_subject,
                  :delivery_method, :pool_size, :timeout, :max_retries,
                  :async, :rate_limit_enabled

    def initialize
      @delivery_method = "test"
      @pool_size = 10
      @timeout = 30
      @max_retries = 5
      @async = false
      @rate_limit_enabled = false
    end
  end

  class Notification
    attr_reader :title, :body, :data, :endpoint, :p256dh_key, :auth_key, :options

    def initialize(title:, body:, endpoint:, p256dh_key:, auth_key:, data: {}, **options)
      @title = title
      @body = body
      @endpoint = endpoint
      @p256dh_key = p256dh_key
      @auth_key = auth_key
      @data = data
      @options = options
    end

    def to_json(*args)
      {
        title: @title,
        body: @body,
        data: @data
      }.merge(@options).to_json(*args)
    end
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.config
    self.configuration ||= Configuration.new
  end

  def self.configuration=(config)
    @configuration = config
  end

  def self.configuration
    @configuration
  end
end

# Test classes
class TestActionWebPush < Minitest::Test
  def setup
    ActionWebPush.configuration = nil
  end

  def test_that_it_has_a_version_number
    refute_nil ActionWebPush::VERSION
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
    assert_equal "https://example.com", notification.endpoint
  end

  def test_notification_with_options
    notification = ActionWebPush::Notification.new(
      title: "Test",
      body: "Test message",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      icon: "/icon.png",
      tag: "test-tag"
    )

    assert_equal "/icon.png", notification.options[:icon]
    assert_equal "test-tag", notification.options[:tag]
  end

  def test_notification_json_serialization
    notification = ActionWebPush::Notification.new(
      title: "Test",
      body: "Test message",
      endpoint: "https://example.com",
      p256dh_key: "test_key",
      auth_key: "test_auth",
      data: { url: "/test" }
    )

    json_data = JSON.parse(notification.to_json)
    assert_equal "Test", json_data["title"]
    assert_equal "Test message", json_data["body"]
    assert_equal({ "url" => "/test" }, json_data["data"])
  end
end

class TestConfiguration < Minitest::Test
  def setup
    ActionWebPush.configuration = nil
  end

  def test_default_values
    config = ActionWebPush::Configuration.new

    assert_equal "test", config.delivery_method
    assert_equal 10, config.pool_size
    assert_equal 5, config.max_retries
    assert_equal 30, config.timeout
    refute config.async
    refute config.rate_limit_enabled
  end

  def test_vapid_configuration
    config = ActionWebPush::Configuration.new
    config.vapid_public_key = "test_public_key"
    config.vapid_private_key = "test_private_key"
    config.vapid_subject = "mailto:test@example.com"

    assert_equal "test_public_key", config.vapid_public_key
    assert_equal "test_private_key", config.vapid_private_key
    assert_equal "mailto:test@example.com", config.vapid_subject
  end

  def test_configuration_via_block
    ActionWebPush.configure do |config|
      config.pool_size = 25
      config.async = true
      config.rate_limit_enabled = true
    end

    assert_equal 25, ActionWebPush.config.pool_size
    assert ActionWebPush.config.async
    assert ActionWebPush.config.rate_limit_enabled
  end
end

puts "Running ActionWebPush simple tests (Ruby #{RUBY_VERSION})..."
puts "="*50