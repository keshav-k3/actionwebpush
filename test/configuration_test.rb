# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_default_values
    config = ActionWebPush::Configuration.new

    assert_equal "test", config.delivery_method
    assert_equal 10, config.pool_size
    assert_equal 5, config.max_retries
    assert_equal 30, config.timeout
    refute config.async
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

  def test_pool_configuration
    config = ActionWebPush::Configuration.new
    config.pool_size = 25
    config.pool_timeout = 60

    assert_equal 25, config.pool_size
    assert_equal 60, config.pool_timeout
  end

  def test_delivery_method_validation
    config = ActionWebPush::Configuration.new

    config.delivery_method = :web_push
    assert_equal :web_push, config.delivery_method

    config.delivery_method = "test"
    assert_equal "test", config.delivery_method
  end

  def test_rate_limiting_configuration
    config = ActionWebPush::Configuration.new
    config.rate_limit_enabled = true
    config.rate_limit_per_minute = 100
    config.rate_limit_burst = 10

    assert config.rate_limit_enabled
    assert_equal 100, config.rate_limit_per_minute
    assert_equal 10, config.rate_limit_burst
  end

  def test_tenant_configuration
    config = ActionWebPush::Configuration.new
    config.multi_tenant = true
    config.tenant_resolver = ->(request) { request.headers["X-Tenant-ID"] }

    assert config.multi_tenant
    assert_respond_to config.tenant_resolver, :call
  end

  def test_analytics_configuration
    config = ActionWebPush::Configuration.new
    config.analytics_enabled = true
    config.analytics_adapter = :memory

    assert config.analytics_enabled
    assert_equal :memory, config.analytics_adapter
  end

  def test_error_handling_configuration
    config = ActionWebPush::Configuration.new
    config.raise_delivery_errors = true
    config.logger = Logger.new(STDOUT)

    assert config.raise_delivery_errors
    assert_kind_of Logger, config.logger
  end
end