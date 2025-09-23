# frozen_string_literal: true

require "concurrent-ruby"
require "net/http/persistent"

module ActionWebPush
  class Pool
    include ActionWebPush::Logging
    attr_reader :delivery_pool, :invalidation_pool, :connection, :invalid_subscription_handler

    def initialize(invalid_subscription_handler: nil)
      config = ActionWebPush.config

      @delivery_pool = Concurrent::ThreadPoolExecutor.new(
        max_threads: config.pool_size,
        queue_size: config.queue_size
      )
      @invalidation_pool = Concurrent::FixedThreadPool.new(1)
      @connection = Net::HTTP::Persistent.new(name: "action_web_push", pool_size: config.connection_pool_size)
      @invalid_subscription_handler = invalid_subscription_handler
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
    end

    private

    def deliver_later(notification, subscription_id = nil)
      delivery_pool.post do
        deliver(notification, subscription_id)
      rescue Exception => e
        logger.error "Error in ActionWebPush::Pool.deliver: #{e.class} #{e.message}"
      end
    rescue Concurrent::RejectedExecutionError
      # Queue is full, silently drop the notification
    end

    def deliver(notification, subscription_id = nil)
      notification.deliver(connection: connection)
    rescue WebPush::ExpiredSubscription, OpenSSL::OpenSSLError
      invalidate_subscription_later(subscription_id) if subscription_id && invalid_subscription_handler
    end

    def invalidate_subscription_later(subscription_id)
      invalidation_pool.post do
        invalid_subscription_handler.call(subscription_id)
      rescue Exception => e
        logger.error "Error in ActionWebPush::Pool.invalid_subscription_handler: #{e.class} #{e.message}"
      end
    end

    def shutdown_pool(pool)
      pool.shutdown
      pool.kill unless pool.wait_for_termination(1)
    end

  end
end