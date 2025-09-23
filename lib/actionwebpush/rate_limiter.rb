# frozen_string_literal: true

require "redis" if defined?(Redis)

module ActionWebPush
  class RateLimiter
    class MemoryStore
      CLEANUP_INTERVAL = 300 # 5 minutes

      def initialize
        @store = {}
        @mutex = Mutex.new
        @last_cleanup = Time.now
      end

      def increment(key, ttl)
        @mutex.synchronize do
          # Periodic automatic cleanup
          auto_cleanup! if should_cleanup?

          @store[key] ||= { count: 0, expires_at: Time.now + ttl }

          if @store[key][:expires_at] < Time.now
            @store[key] = { count: 1, expires_at: Time.now + ttl }
          else
            @store[key][:count] += 1
          end

          @store[key][:count]
        end
      end

      def cleanup!
        @mutex.synchronize do
          auto_cleanup!
        end
      end

      def get(key)
        @mutex.synchronize do
          entry = @store[key]
          return 0 unless entry
          return 0 if entry[:expires_at] < Time.now
          entry[:count]
        end
      end

      def size
        @mutex.synchronize { @store.size }
      end

      private

      def should_cleanup?
        Time.now - @last_cleanup > CLEANUP_INTERVAL
      end

      def auto_cleanup!
        before_count = @store.size
        @store.reject! { |_, v| v[:expires_at] < Time.now }
        @last_cleanup = Time.now

        # Log significant cleanups
        cleaned = before_count - @store.size
        if cleaned > 0 && defined?(ActionWebPush) && ActionWebPush.respond_to?(:logger)
          ActionWebPush.logger.debug "ActionWebPush::RateLimiter cleaned up #{cleaned} expired entries (#{@store.size} remaining)"
        end
      end
    end

    class RedisStore
      def initialize(redis_client = nil)
        @redis = redis_client || Redis.current
      end

      def increment(key, ttl)
        result = @redis.multi do |multi|
          multi.incr(key)
          multi.expire(key, ttl.to_i)
        end
        result[0]
      end

      def get(key)
        value = @redis.get(key)
        value ? value.to_i : 0
      end
    end

    attr_reader :store, :limits

    def initialize(store: nil, limits: {})
      @store = store || (defined?(Redis) ? RedisStore.new : MemoryStore.new)
      @limits = default_limits.merge(limits)
    end

    def check_rate_limit!(resource_type, resource_id, user_id = nil)
      limit_key = rate_limit_key(resource_type, resource_id, user_id)
      limit_config = limits[resource_type]

      return true unless limit_config

      current_count = store.increment(limit_key, limit_config[:window])

      if current_count > limit_config[:max_requests]
        # Instrument rate limit exceeded event
        ActionWebPush::Instrumentation.publish("rate_limit_exceeded",
          resource_type: resource_type,
          resource_id: resource_id,
          user_id: user_id,
          current_count: current_count,
          max_requests: limit_config[:max_requests],
          window: limit_config[:window]
        )

        raise ActionWebPush::RateLimitExceeded,
              "Rate limit exceeded for #{resource_type}: #{current_count}/#{limit_config[:max_requests]} in #{limit_config[:window]}s"
      end

      true
    end

    def within_rate_limit?(resource_type, resource_id, user_id = nil)
      check_rate_limit!(resource_type, resource_id, user_id)
      true
    rescue ActionWebPush::RateLimitExceeded
      false
    end

    def rate_limit_info(resource_type, resource_id, user_id = nil)
      limit_key = rate_limit_key(resource_type, resource_id, user_id)
      limit_config = limits[resource_type]

      return nil unless limit_config

      # Use atomic read-only get instead of increment-subtract
      current_count = store.get(limit_key)

      {
        limit: limit_config[:max_requests],
        remaining: [limit_config[:max_requests] - current_count, 0].max,
        window: limit_config[:window],
        reset_at: Time.now + limit_config[:window]
      }
    end

    private

    def default_limits
      {
        endpoint: { max_requests: 100, window: 3600 },      # 100 per hour per endpoint
        user: { max_requests: 1000, window: 3600 },        # 1000 per hour per user
        global: { max_requests: 10000, window: 3600 },     # 10k per hour globally
        subscription: { max_requests: 50, window: 3600 }   # 50 per hour per subscription
      }
    end

    def rate_limit_key(resource_type, resource_id, user_id = nil)
      parts = ["action_web_push", "rate_limit", resource_type.to_s]
      parts << "user_#{user_id}" if user_id
      parts << resource_id.to_s
      parts.join(":")
    end
  end

  class RateLimitExceeded < Error; end
end