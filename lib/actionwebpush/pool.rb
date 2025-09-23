# frozen_string_literal: true

require "concurrent-ruby"
require "net/http/persistent"

module ActionWebPush
  class Pool
    include ActionWebPush::Logging
    attr_reader :delivery_pool, :invalidation_pool, :connection, :invalid_subscription_handler
    attr_accessor :overflow_count, :total_queued_count

    def initialize(invalid_subscription_handler: nil)
      config = ActionWebPush.config

      @delivery_pool = Concurrent::ThreadPoolExecutor.new(
        max_threads: config.pool_size,
        queue_size: config.queue_size
      )
      @invalidation_pool = Concurrent::FixedThreadPool.new(1)
      @connection = Net::HTTP::Persistent.new(name: "action_web_push", pool_size: config.connection_pool_size)
      @invalid_subscription_handler = invalid_subscription_handler

      # Initialize metrics
      @overflow_count = 0
      @total_queued_count = 0
      @overflow_mutex = Mutex.new
    end

    def queue(notifications, subscriptions = nil)
      if subscriptions
        # Multiple subscriptions with same notification data
        subscriptions.find_each do |subscription|
          notification = subscription.build_notification(notifications)
          deliver_later(notification, subscription.id)
        end
      elsif notifications.is_a?(Array)
        # Array of notifications
        notifications.each { |notification| deliver_later(notification) }
      else
        # Single notification
        deliver_later(notifications)
      end
    end

    def shutdown
      connection.shutdown
      shutdown_pool(delivery_pool)
      shutdown_pool(invalidation_pool)
      log_final_metrics
    end

    def metrics
      @overflow_mutex.synchronize do
        {
          total_queued: @total_queued_count,
          overflow_count: @overflow_count,
          overflow_rate: @total_queued_count > 0 ? (@overflow_count.to_f / @total_queued_count * 100).round(2) : 0.0,
          pool_queue_size: delivery_pool.queue_length,
          pool_active_threads: delivery_pool.length,
          pool_max_threads: delivery_pool.max_length
        }
      end
    end

    private

    def deliver_later(notification, subscription_id = nil)
      @overflow_mutex.synchronize { @total_queued_count += 1 }

      delivery_pool.post do
        deliver(notification, subscription_id)
      rescue Exception => e
        logger.error "Error in ActionWebPush::Pool.deliver: #{e.class} #{e.message}"
      end
    rescue Concurrent::RejectedExecutionError
      handle_queue_overflow(notification, subscription_id)
    end

    def deliver(notification, subscription_id = nil)
      notification.deliver(connection: connection)
    rescue ActionWebPush::ExpiredSubscriptionError => e
      context = {
        endpoint: notification.respond_to?(:endpoint) ? notification.endpoint : nil,
        subscription_id: subscription_id
      }
      ActionWebPush::ErrorHandler.handle_expired_subscription_error(e, context)
      invalidate_subscription_later(subscription_id) if subscription_id && invalid_subscription_handler
    rescue ActionWebPush::RateLimitExceeded => e
      context = {
        resource_type: :endpoint,
        resource_id: notification.respond_to?(:endpoint) ? notification.endpoint : nil
      }
      ActionWebPush::ErrorHandler.handle_rate_limit_error(e, context)
      raise e
    rescue ActionWebPush::DeliveryError => e
      context = {
        endpoint: notification.respond_to?(:endpoint) ? notification.endpoint : nil,
        title: notification.respond_to?(:title) ? notification.title : nil,
        retry_count: 0
      }
      ActionWebPush::ErrorHandler.handle_delivery_failure(e, context)
      raise e
    rescue WebPush::ExpiredSubscription, OpenSSL::OpenSSLError => e
      # Handle legacy WebPush exceptions
      context = {
        endpoint: notification.respond_to?(:endpoint) ? notification.endpoint : nil,
        subscription_id: subscription_id
      }
      error = ActionWebPush::ExpiredSubscriptionError.new(e.message)
      ActionWebPush::ErrorHandler.handle_expired_subscription_error(error, context)
      invalidate_subscription_later(subscription_id) if subscription_id && invalid_subscription_handler
    rescue StandardError => e
      context = {
        endpoint: notification.respond_to?(:endpoint) ? notification.endpoint : nil,
        title: notification.respond_to?(:title) ? notification.title : nil
      }
      handled_error = ActionWebPush::ErrorHandler.handle_unexpected_error(e, context)
      raise handled_error
    end

    def invalidate_subscription_later(subscription_id)
      invalidation_pool.post do
        invalid_subscription_handler.call(subscription_id)
      rescue Exception => e
        logger.error "Error in ActionWebPush::Pool.invalid_subscription_handler: #{e.class} #{e.message}"
      end
    end

    def handle_queue_overflow(notification, subscription_id = nil)
      @overflow_mutex.synchronize { @overflow_count += 1 }

      overflow_rate = @overflow_mutex.synchronize { (@overflow_count.to_f / @total_queued_count * 100).round(2) }

      # Instrument the overflow event
      ActionWebPush::Instrumentation.publish("pool_overflow",
        overflow_count: @overflow_count,
        total_queued: @total_queued_count,
        overflow_rate: overflow_rate,
        queue_length: delivery_pool.queue_length,
        active_threads: delivery_pool.length,
        max_threads: delivery_pool.max_length,
        notification_title: notification.respond_to?(:title) ? notification.title : nil
      )

      logger.warn "ActionWebPush::Pool queue overflow (#{@overflow_count}/#{@total_queued_count}, #{overflow_rate}%): dropping notification"

      # Log additional context for debugging
      logger.warn "Pool stats: queue=#{delivery_pool.queue_length}, active=#{delivery_pool.length}/#{delivery_pool.max_length}"

      # TODO: Could implement fallback strategies here:
      # - Store in Redis for retry
      # - Send to DLQ
      # - Immediate synchronous delivery for critical notifications
    end

    def log_final_metrics
      stats = metrics
      logger.info "ActionWebPush::Pool shutdown metrics: #{stats}"
    end

    def shutdown_pool(pool)
      pool.shutdown
      pool.kill unless pool.wait_for_termination(1)
    end

  end
end